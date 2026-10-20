import time
import datetime
import hashlib
import hmac
from unittest.mock import MagicMock, patch

import pytest
from django.test import RequestFactory

from apps_work.billing.models import Assinatura, Pagamento, Plano
from apps_work.billing.services import MercadoPagoService, WebhookInvalidoError
from apps_work.billing.views import RetornoCheckoutView


class TestBillingPlanoStr:
    def test_str_plano_retorna_display(self):
        assert str(Plano(nome='pro')) == 'Pro'
        assert str(Plano(nome='business')) == 'Business'
        assert str(Plano(nome='enterprise')) == 'Enterprise'


@pytest.mark.django_db
class TestBillingAssinaturaStr:
    def test_str_assinatura(self, tenant):
        plano = Plano.objects.create(nome='pro', preco_mensal='29.90', limite_colaboradores=1)
        assinatura = Assinatura.objects.create(
            tenant=tenant,
            plano=plano,
            status='trial',
            inicio=datetime.date.today(),
            proximo_vencimento=datetime.date.today(),
        )
        result = str(assinatura)
        assert str(tenant) in result
        assert 'Pro' in result

    def test_str_pagamento_billing(self, tenant):
        plano = Plano.objects.create(nome='business', preco_mensal='49.90')
        assinatura = Assinatura.objects.create(
            tenant=tenant,
            plano=plano,
            status='trial',
            inicio=datetime.date.today(),
            proximo_vencimento=datetime.date.today(),
        )
        pagamento = Pagamento.objects.create(
            assinatura=assinatura,
            valor='49.90',
            status='pago',
            data=datetime.date.today(),
        )
        result = str(pagamento)
        assert 'pago' in result
        assert str(tenant) in result


@pytest.mark.django_db
class TestAssinaturaBloqueada:
    def test_ativa_nao_bloqueia(self, tenant):
        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        assinatura = Assinatura.objects.create(
            tenant=tenant, plano=plano, status='ativa',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
        )
        assert assinatura.bloqueada is False

    def test_trial_dentro_do_prazo_nao_bloqueia(self, tenant):
        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        assinatura = Assinatura.objects.create(
            tenant=tenant, plano=plano, status='trial',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
            trial_fim=datetime.date.today() + datetime.timedelta(days=1),
        )
        assert assinatura.bloqueada is False

    def test_trial_vencido_bloqueia(self, tenant):
        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        assinatura = Assinatura.objects.create(
            tenant=tenant, plano=plano, status='trial',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
            trial_fim=datetime.date.today() - datetime.timedelta(days=1),
        )
        assert assinatura.bloqueada is True

    def test_trial_sem_trial_fim_nao_bloqueia(self, tenant):
        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        assinatura = Assinatura.objects.create(
            tenant=tenant, plano=plano, status='trial',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
        )
        assert assinatura.bloqueada is False

    def test_inadimplente_bloqueia(self, tenant):
        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        assinatura = Assinatura.objects.create(
            tenant=tenant, plano=plano, status='inadimplente',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
        )
        assert assinatura.bloqueada is True

    def test_cancelada_dentro_do_prazo_nao_bloqueia(self, tenant):
        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        assinatura = Assinatura.objects.create(
            tenant=tenant, plano=plano, status='cancelada',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today() + datetime.timedelta(days=5),
        )
        assert assinatura.bloqueada is False

    def test_cancelada_apos_o_prazo_bloqueia(self, tenant):
        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        assinatura = Assinatura.objects.create(
            tenant=tenant, plano=plano, status='cancelada',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today() - datetime.timedelta(days=1),
        )
        assert assinatura.bloqueada is True


@pytest.fixture
def mp_settings(settings):
    settings.MERCADOPAGO_ACCESS_TOKEN = 'TEST-token'
    settings.MERCADOPAGO_WEBHOOK_SECRET = 'segredo-teste'


def _mock_sdk(**recursos):
    """Monta um mercadopago.SDK() falso: cada kwarg é o nome do recurso
    (plan, preapproval, payment) e o valor é o mock do objeto
    retornado por sdk.<recurso>()."""
    sdk = MagicMock()
    for nome, mock_recurso in recursos.items():
        setattr(sdk, nome, MagicMock(return_value=mock_recurso))
    return sdk


@pytest.mark.django_db
@pytest.mark.usefixtures('mp_settings')
class TestMercadoPagoServiceCriar:
    def test_criar_plano_no_gateway_salva_id_e_init_point(self):
        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        recurso_plano = MagicMock()
        recurso_plano.create.return_value = {
            'status': 201,
            'response': {'id': 'plan-123', 'init_point': 'https://mp.example/subscriptions/checkout?preapproval_plan_id=plan-123'},
        }

        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk(plan=recurso_plano)):
            plan_id = MercadoPagoService().criar_plano_no_gateway(plano)

        plano.refresh_from_db()
        assert plan_id == 'plan-123'
        assert plano.mercadopago_plan_id == 'plan-123'
        assert plano.mercadopago_init_point == 'https://mp.example/subscriptions/checkout?preapproval_plan_id=plan-123'

    def test_obter_link_assinatura_retorna_init_point_salvo(self):
        plano = Plano.objects.create(
            nome='pro', preco_mensal='69.90',
            mercadopago_plan_id='plan-123',
            mercadopago_init_point='https://mp.example/subscriptions/checkout?preapproval_plan_id=plan-123',
        )

        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk()):
            init_point = MercadoPagoService().obter_link_assinatura(plano)

        assert init_point == 'https://mp.example/subscriptions/checkout?preapproval_plan_id=plan-123'

    def test_obter_link_assinatura_sem_init_point_levanta_erro(self):
        from apps_work.billing.services import AssinaturaInvalidaError

        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')

        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk()):
            with pytest.raises(AssinaturaInvalidaError):
                MercadoPagoService().obter_link_assinatura(plano)


@pytest.mark.django_db
@pytest.mark.usefixtures('mp_settings')
class TestMercadoPagoServiceConfirmar:
    def test_confirmar_assinatura_ativa_e_vincula(self, tenant):
        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        Assinatura.objects.create(
            tenant=tenant, plano=plano, status='trial',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
        )
        recurso_preapproval = MagicMock()
        recurso_preapproval.get.return_value = {'status': 200, 'response': {'status': 'authorized'}}

        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk(preapproval=recurso_preapproval)):
            assinatura = MercadoPagoService().confirmar_assinatura(tenant, 'preapproval-abc')

        assert assinatura.status == 'ativa'
        assert assinatura.mercadopago_preapproval_id == 'preapproval-abc'

    def test_confirmar_assinatura_erro_na_api_levanta_erro(self, tenant):
        from apps_work.billing.services import PreapprovalInvalidoError

        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        Assinatura.objects.create(
            tenant=tenant, plano=plano, status='trial',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
        )
        recurso_preapproval = MagicMock()
        recurso_preapproval.get.return_value = {'status': 404, 'response': {}}

        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk(preapproval=recurso_preapproval)):
            with pytest.raises(PreapprovalInvalidoError):
                MercadoPagoService().confirmar_assinatura(tenant, 'preapproval-inexistente')

    def test_confirmar_assinatura_nao_autorizada_levanta_erro(self, tenant):
        from apps_work.billing.services import PreapprovalInvalidoError

        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        Assinatura.objects.create(
            tenant=tenant, plano=plano, status='trial',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
        )
        recurso_preapproval = MagicMock()
        recurso_preapproval.get.return_value = {'status': 200, 'response': {'status': 'pending'}}

        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk(preapproval=recurso_preapproval)):
            with pytest.raises(PreapprovalInvalidoError):
                MercadoPagoService().confirmar_assinatura(tenant, 'preapproval-pendente')

    def test_confirmar_assinatura_ja_vinculada_a_outro_tenant_levanta_erro(self, tenant):
        from django.db import connection

        from apps_work.billing.services import PreapprovalInvalidoError
        from tenants.models import Tenant

        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        Assinatura.objects.create(
            tenant=tenant, plano=plano, status='trial',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
        )

        connection.set_schema_to_public()
        outro_tenant = Tenant.objects.create(schema_name='outro_negocio_confirmar', name='Outro Negócio')
        Assinatura.objects.create(
            tenant=outro_tenant, plano=plano, status='ativa',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
            mercadopago_preapproval_id='preapproval-do-outro',
        )

        recurso_preapproval = MagicMock()
        recurso_preapproval.get.return_value = {'status': 200, 'response': {'status': 'authorized'}}

        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk(preapproval=recurso_preapproval)):
            with pytest.raises(PreapprovalInvalidoError):
                MercadoPagoService().confirmar_assinatura(tenant, 'preapproval-do-outro')

    def test_confirmar_assinatura_sem_assinatura_local_levanta_erro(self, tenant):
        from apps_work.billing.services import PreapprovalInvalidoError

        recurso_preapproval = MagicMock()
        recurso_preapproval.get.return_value = {'status': 200, 'response': {'status': 'authorized'}}

        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk(preapproval=recurso_preapproval)):
            with pytest.raises(PreapprovalInvalidoError):
                MercadoPagoService().confirmar_assinatura(tenant, 'preapproval-sem-assinatura')


@pytest.mark.django_db
@pytest.mark.usefixtures('mp_settings')
class TestMercadoPagoServiceCancelar:
    def test_cancelar_assinatura_ativa_com_sucesso(self, tenant):
        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        assinatura = Assinatura.objects.create(
            tenant=tenant, plano=plano, status='ativa',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today() + datetime.timedelta(days=10),
            mercadopago_preapproval_id='preapproval-cancelar',
        )
        recurso_preapproval = MagicMock()
        recurso_preapproval.update.return_value = {'status': 200, 'response': {'status': 'cancelled'}}

        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk(preapproval=recurso_preapproval)):
            resultado = MercadoPagoService().cancelar_assinatura(tenant)

        recurso_preapproval.update.assert_called_once_with('preapproval-cancelar', {'status': 'cancelled'})
        assert resultado.status == 'cancelada'
        assinatura.refresh_from_db()
        assert assinatura.status == 'cancelada'
        # proximo_vencimento não muda — é o que garante o acesso até o fim do período
        assert assinatura.proximo_vencimento == datetime.date.today() + datetime.timedelta(days=10)

    def test_cancelar_sem_assinatura_levanta_erro(self, tenant):
        from apps_work.billing.services import PreapprovalInvalidoError

        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk()):
            with pytest.raises(PreapprovalInvalidoError):
                MercadoPagoService().cancelar_assinatura(tenant)

    def test_cancelar_assinatura_nao_ativa_levanta_erro(self, tenant):
        from apps_work.billing.services import PreapprovalInvalidoError

        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        Assinatura.objects.create(
            tenant=tenant, plano=plano, status='trial',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
        )
        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk()):
            with pytest.raises(PreapprovalInvalidoError):
                MercadoPagoService().cancelar_assinatura(tenant)

    def test_cancelar_assinatura_falha_na_api_nao_atualiza_local(self, tenant):
        from apps_work.billing.services import PreapprovalInvalidoError

        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        assinatura = Assinatura.objects.create(
            tenant=tenant, plano=plano, status='ativa',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today() + datetime.timedelta(days=10),
            mercadopago_preapproval_id='preapproval-falha',
        )
        recurso_preapproval = MagicMock()
        recurso_preapproval.update.return_value = {'status': 500, 'response': {}}

        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk(preapproval=recurso_preapproval)):
            with pytest.raises(PreapprovalInvalidoError):
                MercadoPagoService().cancelar_assinatura(tenant)

        assinatura.refresh_from_db()
        assert assinatura.status == 'ativa'


@pytest.mark.django_db
@pytest.mark.usefixtures('mp_settings')
class TestMercadoPagoServiceWebhook:
    def _assinar(self, data_id, x_request_id, ts=None, secret='segredo-teste'):
        ts = ts or str(int(time.time()))
        manifest = f'id:{data_id};request-id:{x_request_id};ts:{ts};'
        v1 = hmac.new(secret.encode(), manifest.encode(), hashlib.sha256).hexdigest()
        return f'ts={ts},v1={v1}'

    def test_assinatura_antiga_e_recusada(self):
        # Reenvio de uma notificação capturada: assinatura certa, ts velho.
        velho = str(int(time.time()) - 11 * 60)
        x_signature = self._assinar(data_id='123', x_request_id='req-1', ts=velho)
        assert MercadoPagoService()._validar_assinatura_webhook(x_signature, 'req-1', '123') is False

    def test_ts_em_milissegundos_e_aceito(self):
        agora_ms = str(int(time.time() * 1000))
        x_signature = self._assinar(data_id='123', x_request_id='req-1', ts=agora_ms)
        assert MercadoPagoService()._validar_assinatura_webhook(x_signature, 'req-1', '123') is True

    def test_assinatura_valida_e_aceita(self):
        x_signature = self._assinar(data_id='123', x_request_id='req-1')
        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk()):
            valido = MercadoPagoService()._validar_assinatura_webhook(x_signature, 'req-1', '123')
        assert valido is True

    def test_assinatura_invalida_e_rejeitada(self):
        x_signature = self._assinar(data_id='123', x_request_id='req-1', secret='outro-segredo')
        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk()):
            valido = MercadoPagoService()._validar_assinatura_webhook(x_signature, 'req-1', '123')
        assert valido is False

    def test_processar_webhook_com_assinatura_invalida_levanta_erro(self):
        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk()):
            with pytest.raises(WebhookInvalidoError):
                MercadoPagoService().processar_webhook(
                    topico='payment', data_id='123',
                    x_signature='ts=1,v1=assinatura-forjada', x_request_id='req-1',
                )

    def test_processar_preapproval_correlaciona_por_email_do_proprietario(self, tenant):
        from django.contrib.auth.models import User
        from tenants.models import UserTenant

        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        assinatura = Assinatura.objects.create(
            tenant=tenant, plano=plano, status='trial',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
        )
        dono = User.objects.create_user(username='dona@teste.com', email='dona@teste.com', password='x')
        UserTenant.objects.create(user=dono, tenant=tenant, role='proprietario')

        recurso_preapproval = MagicMock()
        recurso_preapproval.get.return_value = {
            'status': 200,
            'response': {'id': 'preapproval-999', 'status': 'authorized', 'payer_email': 'dona@teste.com'},
        }
        x_signature = self._assinar(data_id='preapproval-999', x_request_id='req-4')

        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk(preapproval=recurso_preapproval)):
            MercadoPagoService().processar_webhook(
                topico='subscription_preapproval', data_id='preapproval-999',
                x_signature=x_signature, x_request_id='req-4',
            )

        assinatura.refresh_from_db()
        assert assinatura.status == 'ativa'
        assert assinatura.mercadopago_preapproval_id == 'preapproval-999'

    def test_processar_preapproval_sem_proprietario_correspondente_nao_quebra(self):
        recurso_preapproval = MagicMock()
        recurso_preapproval.get.return_value = {
            'status': 200,
            'response': {'id': 'preapproval-000', 'status': 'authorized', 'payer_email': 'ninguem@teste.com'},
        }
        x_signature = self._assinar(data_id='preapproval-000', x_request_id='req-5')

        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk(preapproval=recurso_preapproval)):
            MercadoPagoService().processar_webhook(
                topico='subscription_preapproval', data_id='preapproval-000',
                x_signature=x_signature, x_request_id='req-5',
            )

        assert not Assinatura.objects.filter(mercadopago_preapproval_id='preapproval-000').exists()

    def test_processar_pagamento_aprovado_cria_registro_e_ativa_assinatura(self, tenant):
        from django.contrib.auth.models import User
        from tenants.models import UserTenant

        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        assinatura = Assinatura.objects.create(
            tenant=tenant, plano=plano, status='trial',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
        )
        dono = User.objects.create_user(username='dono@teste.com', email='dono@teste.com', password='x')
        UserTenant.objects.create(user=dono, tenant=tenant, role='proprietario')

        recurso_payment = MagicMock()
        recurso_payment.get.return_value = {
            'status': 200,
            'response': {
                'id': 'payment-789', 'status': 'approved', 'transaction_amount': 69.90,
                'payer': {'email': 'dono@teste.com'}, 'metadata': {},
            },
        }
        x_signature = self._assinar(data_id='payment-789', x_request_id='req-2')

        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk(payment=recurso_payment)):
            MercadoPagoService().processar_webhook(
                topico='payment', data_id='payment-789',
                x_signature=x_signature, x_request_id='req-2',
            )

        assinatura.refresh_from_db()
        assert assinatura.status == 'ativa'
        pagamento = Pagamento.objects.get(mercadopago_payment_id='payment-789')
        assert pagamento.status == 'pago'
        assert pagamento.assinatura == assinatura

    def test_processar_pagamento_ja_registrado_nao_duplica(self, tenant):
        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        assinatura = Assinatura.objects.create(
            tenant=tenant, plano=plano, status='ativa',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
            mercadopago_preapproval_id='preapproval-456',
        )
        Pagamento.objects.create(
            assinatura=assinatura, valor='69.90', status='pago',
            data=datetime.date.today(), mercadopago_payment_id='payment-789',
        )
        recurso_payment = MagicMock()
        x_signature = self._assinar(data_id='payment-789', x_request_id='req-3')

        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk(payment=recurso_payment)):
            MercadoPagoService().processar_webhook(
                topico='payment', data_id='payment-789',
                x_signature=x_signature, x_request_id='req-3',
            )

        recurso_payment.get.assert_not_called()
        assert Pagamento.objects.filter(mercadopago_payment_id='payment-789').count() == 1

    def test_processar_authorized_payment_aprovado_ativa_assinatura(self, tenant):
        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        assinatura = Assinatura.objects.create(
            tenant=tenant, plano=plano, status='trial',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
            mercadopago_preapproval_id='preapproval-999',
        )
        x_signature = self._assinar(data_id='authpay-1', x_request_id='req-6')

        resposta_mock = MagicMock()
        resposta_mock.status_code = 200
        resposta_mock.json.return_value = {
            'preapproval_id': 'preapproval-999',
            'transaction_amount': 69.90,
            'payment': {'status': 'approved'},
        }

        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk()):
            with patch('apps_work.billing.services.requests.get', return_value=resposta_mock) as mock_get:
                MercadoPagoService().processar_webhook(
                    topico='subscription_authorized_payment', data_id='authpay-1',
                    x_signature=x_signature, x_request_id='req-6',
                )

        assert 'authorized_payments/authpay-1' in mock_get.call_args[0][0]
        assinatura.refresh_from_db()
        assert assinatura.status == 'ativa'
        pagamento = Pagamento.objects.get(mercadopago_payment_id='authpay-1')
        assert pagamento.status == 'pago'
        assert pagamento.assinatura == assinatura

    def test_processar_authorized_payment_sem_assinatura_correspondente_nao_quebra(self):
        x_signature = self._assinar(data_id='authpay-2', x_request_id='req-7')
        resposta_mock = MagicMock()
        resposta_mock.status_code = 200
        resposta_mock.json.return_value = {
            'preapproval_id': 'preapproval-inexistente',
            'transaction_amount': 69.90,
            'payment': {'status': 'approved'},
        }
        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk()):
            with patch('apps_work.billing.services.requests.get', return_value=resposta_mock):
                MercadoPagoService().processar_webhook(
                    topico='subscription_authorized_payment', data_id='authpay-2',
                    x_signature=x_signature, x_request_id='req-7',
                )
        assert not Pagamento.objects.filter(mercadopago_payment_id='authpay-2').exists()

    def test_processar_authorized_payment_endpoint_falha_nao_quebra(self):
        x_signature = self._assinar(data_id='authpay-3', x_request_id='req-8')
        resposta_mock = MagicMock()
        resposta_mock.status_code = 404
        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk()):
            with patch('apps_work.billing.services.requests.get', return_value=resposta_mock):
                MercadoPagoService().processar_webhook(
                    topico='subscription_authorized_payment', data_id='authpay-3',
                    x_signature=x_signature, x_request_id='req-8',
                )
        assert not Pagamento.objects.filter(mercadopago_payment_id='authpay-3').exists()

    def test_processar_authorized_payment_ja_registrado_nao_duplica(self, tenant):
        plano = Plano.objects.create(nome='pro', preco_mensal='69.90')
        assinatura = Assinatura.objects.create(
            tenant=tenant, plano=plano, status='ativa',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
            mercadopago_preapproval_id='preapproval-999',
        )
        Pagamento.objects.create(
            assinatura=assinatura, valor='69.90', status='pago',
            data=datetime.date.today(), mercadopago_payment_id='authpay-4',
        )
        x_signature = self._assinar(data_id='authpay-4', x_request_id='req-9')
        with patch('apps_work.billing.services.mercadopago.SDK', return_value=_mock_sdk()):
            with patch('apps_work.billing.services.requests.get') as mock_get:
                MercadoPagoService().processar_webhook(
                    topico='subscription_authorized_payment', data_id='authpay-4',
                    x_signature=x_signature, x_request_id='req-9',
                )
        mock_get.assert_not_called()
        assert Pagamento.objects.filter(mercadopago_payment_id='authpay-4').count() == 1


class TestRetornoCheckoutView:
    def test_redireciona_para_frontend_com_query_string(self, settings):
        settings.FRONTEND_URL = 'http://localhost:5173'
        factory = RequestFactory()
        request = factory.get('/api/billing/retorno/?preapproval_id=abc-123')

        resposta = RetornoCheckoutView.as_view()(request)

        assert resposta.status_code == 302
        assert resposta.url == 'http://localhost:5173/app/pagamentos?preapproval_id=abc-123'

    def test_redireciona_sem_query_string(self, settings):
        settings.FRONTEND_URL = 'http://localhost:5173'
        factory = RequestFactory()
        request = factory.get('/api/billing/retorno/')

        resposta = RetornoCheckoutView.as_view()(request)

        assert resposta.status_code == 302
        assert resposta.url == 'http://localhost:5173/app/pagamentos'


@pytest.mark.django_db
class TestPagamentosListView:
    @pytest.fixture
    def client_autenticado(self, patch_tenant_middleware, proprietario):
        from rest_framework.test import APIClient

        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        client.force_authenticate(user=proprietario)
        return client

    def test_lista_apenas_pagamentos_do_proprio_tenant(self, client_autenticado, tenant):
        from django.db import connection
        from tenants.models import Tenant

        assinatura = Assinatura.objects.get(tenant=tenant)  # já criada por patch_tenant_middleware
        Pagamento.objects.create(assinatura=assinatura, valor='69.90', status='pago', data=datetime.date.today())

        connection.set_schema_to_public()
        plano = Plano.objects.get(nome='pro')
        outro_tenant = Tenant.objects.create(schema_name='outro_negocio_pagamentos', name='Outro Negócio')
        outra_assinatura = Assinatura.objects.create(
            tenant=outro_tenant, plano=plano, status='ativa',
            inicio=datetime.date.today(), proximo_vencimento=datetime.date.today(),
        )
        Pagamento.objects.create(assinatura=outra_assinatura, valor='69.90', status='pago', data=datetime.date.today())

        response = client_autenticado.get('/api/billing/pagamentos/')
        assert response.status_code == 200
        assert response.data['count'] == 1

    def test_ordena_mais_recente_primeiro(self, client_autenticado, tenant):
        assinatura = Assinatura.objects.get(tenant=tenant)
        Pagamento.objects.create(
            assinatura=assinatura, valor='69.90', status='pago',
            data=datetime.date.today() - datetime.timedelta(days=30),
        )
        Pagamento.objects.create(assinatura=assinatura, valor='69.90', status='pago', data=datetime.date.today())

        response = client_autenticado.get('/api/billing/pagamentos/')
        datas = [p['data'] for p in response.data['results']]
        assert datas[0] == str(datetime.date.today())

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware):
        from rest_framework.test import APIClient

        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/billing/pagamentos/')
        assert response.status_code == 401
