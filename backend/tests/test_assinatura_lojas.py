"""Os planos (Pro, Business, Enterprise), o limite da equipe e a compra nas
lojas pelo RevenueCat."""
import datetime
from unittest.mock import patch

import pytest
from django.utils import timezone
from rest_framework.test import APIClient

from apps_work.billing.models import Assinatura, PagamentoAssinatura
from apps_work.billing.revenuecat import RevenueCat, RevenueCatIndisponivelError
from apps_work.billing.services import conceder_acesso_vitalicio, plano_do_tipo, plano_do_trial
from apps_work.usuarios.models import Colaborador
from core.excecoes import ErroDeNegocio

HOJE = datetime.date.today()


@pytest.fixture
def api_dono(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    # O dono também tem o registro de colaborador, e ele nunca conta.
    Colaborador.objects.create(user=proprietario, ativo=True)
    return client


def _no_plano(tenant, tipo, status='ativa'):
    assinatura = Assinatura.objects.get(tenant=tenant)
    assinatura.plano = plano_do_tipo(tipo)
    assinatura.status = status
    assinatura.trial_fim = HOJE + datetime.timedelta(days=10) if status == 'trial' else None
    assinatura.proximo_vencimento = HOJE + datetime.timedelta(days=10)
    assinatura.save()
    # O tenant do teste é o mesmo objeto em toda requisição: sem isso, a
    # view leria a assinatura antiga guardada nele.
    tenant.refresh_from_db()
    return assinatura


def _equipe(quantas, ativo=True):
    return [Colaborador.objects.create(nome=f'Pessoa {i}', ativo=ativo) for i in range(quantas)]


def _quando(dias):
    return (timezone.now() + datetime.timedelta(days=dias)).isoformat()


# ---------------------------------------------------------------------------
# O plano que vale
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestPlanoVigente:
    def test_teste_gratis_vale_business(self, patch_tenant_middleware):
        assinatura = _no_plano(patch_tenant_middleware, 'pro', status='trial')
        assert assinatura.plano_vigente == 'business'
        assert assinatura.limite_da_equipe == 5

    def test_assinado_vale_o_plano(self, patch_tenant_middleware):
        assert _no_plano(patch_tenant_middleware, 'pro').limite_da_equipe == 0
        assert _no_plano(patch_tenant_middleware, 'enterprise').limite_da_equipe == 10

    def test_vitalicio_vira_enterprise(self, patch_tenant_middleware):
        assinatura = _no_plano(patch_tenant_middleware, 'pro', status='trial')
        conceder_acesso_vitalicio(assinatura)
        assinatura.refresh_from_db()
        assert assinatura.plano.nome == 'enterprise'
        assert assinatura.limite_da_equipe == 10

    def test_teste_gratis_nasce_business(self, db):
        assert plano_do_trial().nome == 'business'


# ---------------------------------------------------------------------------
# O limite da equipe
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestLimiteDaEquipe:
    def test_pro_e_so_o_dono(self, api_dono, tenant):
        _no_plano(tenant, 'pro')
        resposta = api_dono.post('/api/v1/colaboradores/', {'nome': 'Ana'}, format='json')
        assert resposta.status_code == 400
        assert resposta.json()['code'] == 'limite_da_equipe'

    def test_business_vai_ate_cinco(self, api_dono, tenant):
        _no_plano(tenant, 'business')
        _equipe(4)
        assert api_dono.post('/api/v1/colaboradores/', {'nome': 'Quinta'}, format='json').status_code == 201
        resposta = api_dono.post('/api/v1/colaboradores/', {'nome': 'Sexta'}, format='json')
        assert resposta.status_code == 400
        assert resposta.json()['code'] == 'limite_da_equipe'

    def test_enterprise_vai_ate_dez(self, api_dono, tenant):
        _no_plano(tenant, 'enterprise')
        _equipe(10)
        resposta = api_dono.post('/api/v1/colaboradores/', {'nome': 'Décima primeira'}, format='json')
        assert resposta.json()['code'] == 'limite_da_equipe'

    def test_inativos_nao_contam(self, api_dono, tenant):
        _no_plano(tenant, 'business')
        _equipe(5, ativo=False)
        assert api_dono.post('/api/v1/colaboradores/', {'nome': 'Ana'}, format='json').status_code == 201

    def test_reativar_respeita_o_limite(self, api_dono, tenant):
        _no_plano(tenant, 'business')
        ativos = _equipe(5)
        (parado,) = _equipe(1, ativo=False)

        resposta = api_dono.post(f'/api/v1/colaboradores/{parado.id}/ativar/')
        assert resposta.status_code == 400
        assert resposta.json()['code'] == 'limite_da_equipe'

        api_dono.post(f'/api/v1/colaboradores/{ativos[0].id}/desativar/')
        assert api_dono.post(f'/api/v1/colaboradores/{parado.id}/ativar/').status_code == 200

    def test_plano_menor_nao_desativa_ninguem(self, api_dono, tenant):
        _no_plano(tenant, 'business')
        _equipe(5)
        _no_plano(tenant, 'pro')
        assert Colaborador.objects.filter(ativo=True).count() == 6  # a equipe e o dono

    def test_convite_sem_cadastro_respeita_o_limite(self, api_dono, tenant):
        _no_plano(tenant, 'pro')
        resposta = api_dono.post('/api/v1/convites/', {'email': 'ana@x.com'}, format='json')
        assert resposta.status_code == 400
        assert resposta.json()['code'] == 'limite_da_equipe'

    @patch('core.email.send_mail')
    def test_aceite_respeita_o_limite(self, _email, api_dono, tenant):
        from apps_work.usuarios.services import AceitarConviteService, ConviteService
        _no_plano(tenant, 'business')
        _equipe(4)
        convite = ConviteService().criar_e_enviar(nome='Ana', email='ana@x.com', tenant_nome='Empresa')
        _equipe(1)  # a equipe encheu antes do aceite

        with pytest.raises(ErroDeNegocio) as erro:
            AceitarConviteService().aceitar(convite.token, 'SenhaForte@2024!')
        assert erro.value.code == 'limite_da_equipe'

    def test_assinatura_mostra_plano_e_equipe(self, api_dono, tenant):
        _no_plano(tenant, 'business')
        _equipe(2)
        corpo = api_dono.get('/api/v1/billing/assinatura/').json()
        assert (corpo['plano'], corpo['plano_nome']) == ('business', 'Business')
        assert (corpo['limite_equipe'], corpo['equipe_ativa']) == (5, 2)
        assert corpo['vitalicia'] is False


# ---------------------------------------------------------------------------
# Sincronizar com o RevenueCat
# ---------------------------------------------------------------------------

def _sincronizar(tenant, assinante):
    with patch.object(RevenueCat, 'buscar_assinante', return_value=assinante) as buscar:
        assinatura = RevenueCat().sincronizar(tenant)
    return assinatura, buscar


def _compra(plano, fim, **extra):
    produto = f'wm_{plano}_mensal'
    return {
        'entitlements': {plano: {'expires_date': fim, 'product_identifier': produto, 'purchase_date': _quando(0)}},
        'subscriptions': {produto: {'expires_date': fim, **extra}},
    }


@pytest.mark.django_db
class TestSincronizar:
    def test_sem_compra_mantem_o_teste(self, patch_tenant_middleware):
        _no_plano(patch_tenant_middleware, 'business', status='trial')
        assinatura, _ = _sincronizar(patch_tenant_middleware, {})
        assert assinatura.status == 'trial'
        assert assinatura.gateway != 'revenuecat'

    def test_compra_libera_o_plano(self, patch_tenant_middleware):
        _no_plano(patch_tenant_middleware, 'business', status='trial')
        fim = timezone.now() + datetime.timedelta(days=30)
        assinatura, _ = _sincronizar(patch_tenant_middleware, _compra('pro', fim.isoformat()))

        assinatura.refresh_from_db()
        assert (assinatura.status, assinatura.plano.nome) == ('ativa', 'pro')
        assert assinatura.proximo_vencimento == timezone.localtime(fim).date()
        assert (assinatura.gateway, assinatura.id_externo) == ('revenuecat', patch_tenant_middleware.schema_name)

    def test_cancelada_na_loja_vale_ate_o_fim(self, patch_tenant_middleware):
        assinatura, _ = _sincronizar(
            patch_tenant_middleware, _compra('business', _quando(20), unsubscribe_detected_at=_quando(0)),
        )
        assert assinatura.status == 'cancelada'
        assert not assinatura.bloqueada

    def test_vencida_bloqueia(self, patch_tenant_middleware):
        _no_plano(patch_tenant_middleware, 'business')
        assinatura, _ = _sincronizar(patch_tenant_middleware, _compra('business', _quando(-2)))
        assert assinatura.status == 'cancelada'
        assert assinatura.bloqueada

    def test_vencida_durante_o_teste_devolve_o_teste(self, patch_tenant_middleware):
        _no_plano(patch_tenant_middleware, 'business', status='trial')
        assinatura, _ = _sincronizar(patch_tenant_middleware, _compra('pro', _quando(-1)))
        assert assinatura.status == 'trial'
        assert not assinatura.bloqueada

    def test_carencia_mantem_o_acesso(self, patch_tenant_middleware):
        compra = _compra('business', _quando(-1))
        compra['entitlements']['business']['grace_period_expires_date'] = _quando(3)
        assinatura, _ = _sincronizar(patch_tenant_middleware, compra)
        assert assinatura.status == 'ativa'

    def test_vale_o_maior_plano(self, patch_tenant_middleware):
        compra = _compra('pro', _quando(5))
        compra['entitlements'].update(_compra('enterprise', _quando(30))['entitlements'])
        assinatura, _ = _sincronizar(patch_tenant_middleware, compra)
        assert assinatura.plano.nome == 'enterprise'

    def test_vitalicio_nao_muda(self, patch_tenant_middleware):
        conceder_acesso_vitalicio(Assinatura.objects.get(tenant=patch_tenant_middleware))
        assinatura, buscar = _sincronizar(patch_tenant_middleware, _compra('pro', _quando(-5)))
        assert assinatura.vitalicia
        buscar.assert_not_called()


# ---------------------------------------------------------------------------
# Webhook e rota de sincronizar
# ---------------------------------------------------------------------------

@pytest.fixture
def webhook(settings):
    settings.REVENUECAT_WEBHOOK_AUTH = 'Bearer segredo-rc'
    settings.ALLOWED_HOSTS = ['*']
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'localhost'
    return client


def _evento(tenant, **campos):
    return {'api_version': '1.0', 'event': {
        'type': 'RENEWAL', 'app_user_id': tenant.schema_name, 'transaction_id': 'T1',
        'price_in_purchased_currency': 69.9, 'purchased_at_ms': int(timezone.now().timestamp() * 1000),
        'period_type': 'NORMAL', **campos,
    }}


@pytest.mark.django_db
class TestWebhook:
    URL = '/api/v1/billing/webhook/revenuecat/'

    def test_recusa_sem_o_segredo(self, webhook, tenant):
        resposta = webhook.post(self.URL, _evento(tenant), format='json', HTTP_AUTHORIZATION='Bearer outro')
        assert resposta.status_code == 401

    def test_sincroniza_e_registra_a_cobranca_uma_vez(self, webhook, patch_tenant_middleware):
        tenant = patch_tenant_middleware
        with patch.object(RevenueCat, 'buscar_assinante', return_value=_compra('business', _quando(30))):
            for _ in range(2):  # o RevenueCat reenvia
                resposta = webhook.post(
                    self.URL, _evento(tenant), format='json', HTTP_AUTHORIZATION='Bearer segredo-rc',
                )
                assert resposta.status_code == 200

        assinatura = Assinatura.objects.get(tenant=tenant)
        assert assinatura.plano.nome == 'business'
        pagamentos = PagamentoAssinatura.objects.filter(assinatura=assinatura, gateway='revenuecat')
        assert [(str(p.valor), p.status) for p in pagamentos] == [('69.90', 'pago')]

    def test_teste_da_loja_nao_vira_cobranca(self, webhook, patch_tenant_middleware):
        with patch.object(RevenueCat, 'buscar_assinante', return_value=_compra('pro', _quando(30))):
            webhook.post(
                self.URL, _evento(patch_tenant_middleware, type='INITIAL_PURCHASE', period_type='TRIAL'),
                format='json', HTTP_AUTHORIZATION='Bearer segredo-rc',
            )
        assert not PagamentoAssinatura.objects.filter(gateway='revenuecat').exists()

    def test_revenuecat_fora_do_ar_pede_reenvio(self, webhook, patch_tenant_middleware):
        with patch.object(RevenueCat, 'buscar_assinante', side_effect=RevenueCatIndisponivelError('fora')):
            resposta = webhook.post(
                self.URL, _evento(patch_tenant_middleware), format='json', HTTP_AUTHORIZATION='Bearer segredo-rc',
            )
        assert resposta.status_code == 503

    def test_transferencia_sincroniza_os_dois_lados(self, webhook, patch_tenant_middleware):
        corpo = {'event': {'type': 'TRANSFER', 'transferred_from': ['outro'], 'transferred_to': [
            patch_tenant_middleware.schema_name,
        ]}}
        with patch.object(RevenueCat, 'sincronizar') as sincronizar:
            webhook.post(self.URL, corpo, format='json', HTTP_AUTHORIZATION='Bearer segredo-rc')
        sincronizar.assert_called_once_with(patch_tenant_middleware)


@pytest.mark.django_db
class TestRotaSincronizar:
    URL = '/api/v1/billing/assinatura/sincronizar/'

    def test_devolve_a_assinatura_lida_na_loja(self, api_dono, tenant):
        _no_plano(tenant, 'business', status='trial')
        with patch.object(RevenueCat, 'buscar_assinante', return_value=_compra('enterprise', _quando(30))):
            resposta = api_dono.post(self.URL)
        assert resposta.status_code == 200
        assert (resposta.json()['status'], resposta.json()['plano']) == ('ativa', 'enterprise')

    def test_loja_fora_do_ar(self, api_dono):
        with patch.object(RevenueCat, 'buscar_assinante', side_effect=RevenueCatIndisponivelError('fora')):
            resposta = api_dono.post(self.URL)
        assert resposta.status_code == 503
        assert resposta.json()['code'] == 'loja_indisponivel'


@pytest.mark.django_db
class TestCheckoutAntigoFechado:
    """Com a venda nas lojas, o checkout do Mercado Pago não abre nem por um
    app antigo."""

    @pytest.fixture(autouse=True)
    def venda_aberta(self, settings):
        settings.ASSINATURA_ABERTA = True
        settings.BILLING_GATEWAY = 'revenuecat'

    @pytest.mark.parametrize('acao', ['iniciar', 'confirmar', 'cancelar'])
    def test_recusa(self, api_dono, acao):
        resposta = api_dono.post(f'/api/v1/billing/assinatura/{acao}/', {'id_externo': 'X'})
        assert resposta.status_code == 403
        assert resposta.json()['code'] == 'assinatura_pela_loja'


@pytest.mark.django_db
def test_pagina_de_termos(settings):
    from django.test import Client
    settings.ALLOWED_HOSTS = ['*']
    resposta = Client(HTTP_HOST='localhost').get('/termos')
    assert resposta.status_code == 200
    assert 'renova automaticamente' in resposta.content.decode()
