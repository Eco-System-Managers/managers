import datetime
import uuid
from datetime import timedelta
from unittest.mock import MagicMock, patch

import pytest
from django.contrib.auth.models import User
from django.db import DatabaseError, connection
from django.test import RequestFactory
from django.test.utils import CaptureQueriesContext
from django.utils import timezone

from apps_work.billing.models import Assinatura, Plano
from apps_work.usuarios.models import Colaborador
from apps_work.autenticacao.models import LastActivity
from core.middleware import (
    AssinaturaBloqueadaMiddleware,
    InactivityMiddleware,
    JWTTenantMiddleware,
    _token_do_request,
)
from core.permissions import IsProprietario
from tenants.models import UserTenant


# ---------------------------------------------------------------------------
# JWTTenantMiddleware
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestJWTTenantMiddleware:
    def test_seta_schema_do_token_quando_conexao_publica(self, usuario):
        from rest_framework_simplejwt.tokens import AccessToken

        token = AccessToken.for_user(usuario)
        token['schema_name'] = 'empresa_abc'

        factory = RequestFactory()
        request = factory.get('/', HTTP_AUTHORIZATION=f'Bearer {str(token)}')

        get_response = MagicMock(return_value=MagicMock())
        middleware = JWTTenantMiddleware(get_response)

        with patch('core.middleware.connection') as mock_conn:
            mock_conn.schema_name = 'public'
            middleware(request)
            mock_conn.set_schema.assert_called_once_with('empresa_abc')

    def test_nao_age_quando_schema_ja_e_tenant(self, usuario):
        from rest_framework_simplejwt.tokens import AccessToken

        token = AccessToken.for_user(usuario)
        token['schema_name'] = 'empresa_abc'

        factory = RequestFactory()
        request = factory.get('/', HTTP_AUTHORIZATION=f'Bearer {str(token)}')

        get_response = MagicMock(return_value=MagicMock())
        middleware = JWTTenantMiddleware(get_response)

        with patch('core.middleware.connection') as mock_conn:
            mock_conn.schema_name = 'empresa_abc'
            middleware(request)
            mock_conn.set_schema.assert_not_called()


# ---------------------------------------------------------------------------
# AssinaturaBloqueadaMiddleware
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestAssinaturaBloqueadaMiddleware:
    def _chamar(self, path, schema_name):
        get_response = MagicMock(return_value='ok')
        middleware = AssinaturaBloqueadaMiddleware(get_response)
        factory = RequestFactory()
        request = factory.get(path)

        with patch('core.middleware.connection') as mock_conn:
            mock_conn.schema_name = schema_name
            resposta = middleware(request)

        return resposta, get_response

    def test_nao_age_no_schema_public(self, tenant):
        resposta, get_response = self._chamar('/api/servicos/', 'public')
        assert resposta == 'ok'
        get_response.assert_called_once()

    def test_nao_age_fora_do_prefixo_api(self, tenant):
        resposta, get_response = self._chamar('/auth/login/', tenant.schema_name)
        assert resposta == 'ok'
        get_response.assert_called_once()

    def test_nao_age_em_rotas_de_billing(self, tenant):
        resposta, get_response = self._chamar('/api/billing/assinatura/', tenant.schema_name)
        assert resposta == 'ok'
        get_response.assert_called_once()

    def test_nao_age_em_colaboradores_me(self, tenant):
        resposta, get_response = self._chamar('/api/colaboradores/me/', tenant.schema_name)
        assert resposta == 'ok'
        get_response.assert_called_once()

    def test_nao_age_em_empresa_config(self, tenant):
        resposta, get_response = self._chamar('/api/empresa/config/', tenant.schema_name)
        assert resposta == 'ok'
        get_response.assert_called_once()

    def test_bloqueia_quando_sem_nenhuma_assinatura(self, tenant):
        resposta, get_response = self._chamar('/api/servicos/', tenant.schema_name)
        assert resposta.status_code == 402
        get_response.assert_not_called()

    def test_bloqueia_quando_trial_vencido(self, tenant):
        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        Assinatura.objects.create(
            tenant=tenant, plano=plano, status='trial',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
            trial_fim=datetime.date.today() - datetime.timedelta(days=1),
        )
        resposta, get_response = self._chamar('/api/servicos/', tenant.schema_name)
        assert resposta.status_code == 402
        get_response.assert_not_called()

    def test_deixa_passar_quando_ativa(self, tenant):
        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        Assinatura.objects.create(
            tenant=tenant, plano=plano, status='ativa',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
        )
        resposta, get_response = self._chamar('/api/servicos/', tenant.schema_name)
        assert resposta == 'ok'
        get_response.assert_called_once()

    def test_deixa_passar_quando_trial_dentro_do_prazo(self, tenant):
        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        Assinatura.objects.create(
            tenant=tenant, plano=plano, status='trial',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
            trial_fim=datetime.date.today() + datetime.timedelta(days=1),
        )
        resposta, get_response = self._chamar('/api/servicos/', tenant.schema_name)
        assert resposta == 'ok'
        get_response.assert_called_once()


# ---------------------------------------------------------------------------
# Decodificacao compartilhada do token
# ---------------------------------------------------------------------------

def _request_com_token(token_str, path='/api/servicos/'):
    return RequestFactory().get(path, HTTP_AUTHORIZATION=f'Bearer {token_str}')


@pytest.mark.django_db
class TestTokenDoRequest:
    def test_decodifica_uma_vez_e_reaproveita(self, usuario):
        """Dois middlewares pedem o mesmo token; a segunda chamada nao pode
        pagar de novo pela validacao da assinatura."""
        from rest_framework_simplejwt.tokens import AccessToken

        request = _request_com_token(str(AccessToken.for_user(usuario)))

        primeiro = _token_do_request(request)
        with patch('core.middleware.AccessToken') as construtor:
            segundo = _token_do_request(request)

        assert segundo is primeiro
        construtor.assert_not_called()

    def test_token_invalido_vira_none_sem_estourar(self):
        assert _token_do_request(_request_com_token('nao-e-um-jwt')) is None

    def test_sem_authorization_devolve_none(self):
        assert _token_do_request(RequestFactory().get('/api/servicos/')) is None

    def test_none_tambem_fica_memorizado(self):
        """Requisicao anonima nao pode tentar decodificar duas vezes."""
        request = _request_com_token('nao-e-um-jwt')
        _token_do_request(request)
        with patch('core.middleware.AccessToken') as construtor:
            assert _token_do_request(request) is None
        construtor.assert_not_called()


# ---------------------------------------------------------------------------
# InactivityMiddleware
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestInactivityMiddleware:
    def _chamar(self, usuario):
        from rest_framework_simplejwt.tokens import AccessToken

        get_response = MagicMock(return_value='ok')
        request = _request_com_token(str(AccessToken.for_user(usuario)))
        return InactivityMiddleware(get_response)(request), get_response

    def test_primeiro_acesso_cria_o_registro(self, usuario):
        resposta, _ = self._chamar(usuario)
        assert resposta == 'ok'
        assert LastActivity.objects.filter(user=usuario).exists()

    def test_nao_grava_de_novo_dentro_da_janela(self, usuario, settings):
        """A escrita amortizada e o ganho principal: era um UPDATE por
        requisicao so para adiantar o relogio em milissegundos."""
        settings.INACTIVITY_WRITE_WINDOW_SECONDS = 60
        LastActivity.objects.create(user=usuario, ultimo_acesso=timezone.now() - timedelta(seconds=5))

        with CaptureQueriesContext(connection) as ctx:
            self._chamar(usuario)

        updates = [q for q in ctx.captured_queries if q['sql'].lstrip().upper().startswith('UPDATE')]
        assert updates == []

    def test_grava_quando_passa_da_janela(self, usuario, settings):
        settings.INACTIVITY_WRITE_WINDOW_SECONDS = 60
        anterior = timezone.now() - timedelta(seconds=120)
        LastActivity.objects.create(user=usuario, ultimo_acesso=anterior)

        self._chamar(usuario)

        assert LastActivity.objects.get(user=usuario).ultimo_acesso > anterior

    def test_expira_a_sessao_depois_do_timeout(self, usuario, settings):
        settings.INACTIVITY_TIMEOUT_MINUTES = 30
        LastActivity.objects.create(user=usuario, ultimo_acesso=timezone.now() - timedelta(minutes=31))

        resposta, get_response = self._chamar(usuario)

        assert resposta.status_code == 401
        get_response.assert_not_called()

    def test_janela_nao_antecipa_o_logout(self, usuario, settings):
        """Registro velho mas dentro do timeout continua valendo — a janela de
        escrita nao pode ser confundida com o limite de inatividade."""
        settings.INACTIVITY_TIMEOUT_MINUTES = 30
        settings.INACTIVITY_WRITE_WINDOW_SECONDS = 60
        LastActivity.objects.create(user=usuario, ultimo_acesso=timezone.now() - timedelta(minutes=20))

        resposta, get_response = self._chamar(usuario)

        assert resposta == 'ok'
        get_response.assert_called_once()


# ---------------------------------------------------------------------------
# Cache do estado da assinatura
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestCacheDaAssinatura:
    def _assinatura(self, tenant, status='ativa'):
        plano, _ = Plano.objects.get_or_create(nome='pro', defaults={'preco_mensal': '69.90'})
        return Assinatura.objects.create(
            tenant=tenant, plano=plano, status=status,
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
        )

    def _chamar(self, schema_name):
        get_response = MagicMock(return_value='ok')
        middleware = AssinaturaBloqueadaMiddleware(get_response)
        request = RequestFactory().get('/api/servicos/')
        with patch('core.middleware.connection') as mock_conn:
            mock_conn.schema_name = schema_name
            return middleware(request), get_response

    def test_segunda_chamada_nao_consulta_o_banco(self, tenant):
        self._assinatura(tenant)
        self._chamar(tenant.schema_name)

        with CaptureQueriesContext(connection) as ctx:
            self._chamar(tenant.schema_name)

        consultas = [q for q in ctx.captured_queries if 'billing_assinatura' in q['sql']]
        assert consultas == []

    def test_uma_consulta_apenas_no_primeiro_acesso(self, tenant):
        """O Tenant era buscado so para filtrar a Assinatura; o join dispensa."""
        self._assinatura(tenant)

        with CaptureQueriesContext(connection) as ctx:
            self._chamar(tenant.schema_name)

        assinaturas = [q for q in ctx.captured_queries if 'billing_assinatura' in q['sql']]
        assert len(assinaturas) == 1

    def test_pagar_libera_na_hora_sem_esperar_o_ttl(self, tenant):
        """O cenario que o cache nao pode estragar: quem paga precisa sair do
        bloqueio imediatamente, e nao quando a chave expirar."""
        assinatura = self._assinatura(tenant, status='inadimplente')
        assert self._chamar(tenant.schema_name)[0].status_code == 402

        assinatura.status = 'ativa'
        assinatura.save(update_fields=['status'])

        resposta, get_response = self._chamar(tenant.schema_name)
        assert resposta == 'ok'
        get_response.assert_called_once()

    def test_cancelar_a_assinatura_tambem_invalida(self, tenant):
        assinatura = self._assinatura(tenant)
        assert self._chamar(tenant.schema_name)[0] == 'ok'

        assinatura.delete()

        assert self._chamar(tenant.schema_name)[0].status_code == 402


# ---------------------------------------------------------------------------
# Custo dos middlewares numa requisicao real
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestCustoPorRequisicao:
    """Guarda de regressao pela pilha inteira.

    Os testes acima cobrem cada middleware isolado; este existe para pegar o
    caso em que eles estao certos sozinhos e caros juntos — que era exatamente
    a situacao anterior: quatro consultas de infraestrutura antes de a view
    comecar, numa requisicao cuja unica consulta util era a propria listagem.
    """

    def _cliente_autenticado(self, tenant, usuario):
        from rest_framework.test import APIClient
        from rest_framework_simplejwt.tokens import RefreshToken

        refresh = RefreshToken.for_user(usuario)
        refresh['schema_name'] = tenant.schema_name
        refresh['empresa'] = tenant.name

        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        client.credentials(HTTP_AUTHORIZATION=f'Bearer {str(refresh.access_token)}')
        return client

    @pytest.fixture
    def cenario(self, patch_tenant_middleware, tenant, proprietario):
        usuario = proprietario
        plano, _ = Plano.objects.get_or_create(nome='pro', defaults={'preco_mensal': '69.90'})
        Assinatura.objects.update_or_create(
            tenant=tenant,
            defaults={
                'plano': plano, 'status': 'ativa',
                'inicio': datetime.date.today(), 'proximo_vencimento': datetime.date.today(),
            },
        )
        client = self._cliente_autenticado(tenant, usuario)
        # Aquece: primeira chamada cria o LastActivity e memoriza a assinatura.
        client.get('/api/servicos/')
        return client

    def _queries(self, client):
        with CaptureQueriesContext(connection) as ctx:
            resposta = client.get('/api/servicos/')
        assert resposta.status_code == 200
        return [q['sql'] for q in ctx.captured_queries]

    def test_nao_consulta_a_assinatura_em_requisicao_aquecida(self, cenario):
        assert [s for s in self._queries(cenario) if 'billing_assinatura' in s] == []

    def test_nao_consulta_o_tenant_em_requisicao_aquecida(self, cenario):
        # A unica consulta que toca tenants_tenant e a checagem de vinculo da
        # TenantJWTAuthentication, que junta UserTenant e Tenant numa so.
        consultas = [s for s in self._queries(cenario) if 'tenants_tenant' in s]
        assert len(consultas) == 1
        assert 'tenants_usertenant' in consultas[0]

    def test_nao_escreve_o_relogio_de_atividade_a_cada_requisicao(self, cenario):
        updates = [s for s in self._queries(cenario) if s.lstrip().upper().startswith('UPDATE')]
        assert updates == []


# ---------------------------------------------------------------------------
# IsProprietario
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestIsProprietario:
    def test_retorna_false_para_usuario_nao_autenticado(self):
        perm = IsProprietario()
        request = MagicMock()
        request.user.is_authenticated = False
        assert perm.has_permission(request, MagicMock()) is False

    def test_retorna_true_para_proprietario(self, tenant, usuario):
        UserTenant.objects.create(user=usuario, tenant=tenant, role='proprietario')
        request = MagicMock()
        request.user = usuario
        assert IsProprietario().has_permission(request, MagicMock()) is True

    def test_retorna_false_para_colaborador_comum(self, tenant, usuario):
        UserTenant.objects.create(user=usuario, tenant=tenant, role='colaborador')
        request = MagicMock()
        request.user = usuario
        assert IsProprietario().has_permission(request, MagicMock()) is False

    def test_retorna_false_sem_vinculo_com_o_tenant(self, tenant, usuario):
        # Antes, usuario sem Colaborador era tratado como dono — inclusive quem
        # nem pertencia ao tenant.
        request = MagicMock()
        request.user = usuario
        assert IsProprietario().has_permission(request, MagicMock()) is False

    def test_papel_de_colaborador_no_model_nao_concede_nem_nega(self, tenant, usuario):
        """O papel vem do UserTenant; o Colaborador.role nao e consultado."""
        UserTenant.objects.create(user=usuario, tenant=tenant, role='colaborador')
        Colaborador.objects.create(user=usuario, role='proprietario')
        request = MagicMock()
        request.user = usuario
        assert IsProprietario().has_permission(request, MagicMock()) is False

    def test_usa_o_papel_deixado_pela_autenticacao(self, tenant, usuario):
        usuario.papel_no_tenant = 'proprietario'
        request = MagicMock()
        request.user = usuario
        with patch.object(UserTenant, 'papel_no_schema') as consulta:
            assert IsProprietario().has_permission(request, MagicMock()) is True
        consulta.assert_not_called()

    def test_erro_inesperado_nao_concede_permissao(self, tenant, usuario):
        request = MagicMock()
        request.user = usuario
        with patch.object(UserTenant, 'papel_no_schema', side_effect=DatabaseError('conexão caiu')):
            with pytest.raises(DatabaseError):
                IsProprietario().has_permission(request, MagicMock())


# ---------------------------------------------------------------------------
# tenants.models __str__
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestTenantModelStr:
    def test_str_user_tenant(self, usuario):
        from tenants.models import ConviteIndex, UserTenant
        from tenants.models import Tenant

        tenant = Tenant.objects.filter(schema_name='public').first()
        if not tenant:
            pytest.skip('tenant público não existe neste ambiente')

        ut = UserTenant(user=usuario, tenant=tenant, role='colaborador')
        assert str(ut) == f'{usuario.email} → {tenant.name} (colaborador)'

    def test_str_convite_index(self, db):
        from tenants.models import ConviteIndex

        token = uuid.uuid4()
        ci = ConviteIndex(token=token, schema_name='empresa_xyz')
        assert str(ci) == f'{token} → empresa_xyz'
