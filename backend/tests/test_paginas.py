"""Páginas públicas servidas pela API (apps_work/paginas).

As requisições vão para `localhost`, que não é domínio de tenant: chegam no
schema público, como em produção.
"""
from datetime import timedelta

import pytest
from django.contrib.auth.models import User
from django.test import Client
from django.utils import timezone
from django_tenants.utils import schema_context

from apps_work.clientes.models import Cliente
from apps_work.contratos.models import Contrato, StatusContrato
from apps_work.usuarios.models import ConviteColaborador
from tenants.models import ConviteIndex


@pytest.fixture
def navegador():
    return Client(HTTP_HOST='localhost')


@pytest.fixture
def convite(tenant):
    convite = ConviteColaborador.objects.create(
        nome='Ana Lima', email='ana@email.com', expira_em=timezone.now() + timedelta(days=2),
    )
    ConviteIndex.objects.create(token=convite.token, schema_name=tenant.schema_name)
    return convite


@pytest.mark.django_db
class TestPaginaConvite:
    def test_mostra_empresa_e_email(self, navegador, convite):
        resposta = navegador.get(f'/convite/{convite.token}')

        assert resposta.status_code == 200
        assert 'Empresa Teste' in resposta.text
        assert 'ana@email.com' in resposta.text

    def test_token_fora_do_formato_mostra_link_indisponivel(self, navegador, tenant):
        resposta = navegador.get('/convite/nao-e-um-uuid')

        assert resposta.status_code == 404
        assert 'Link indisponível' in resposta.text

    def test_criar_senha_cria_a_conta(self, navegador, convite, tenant):
        resposta = navegador.post(
            f'/convite/{convite.token}', {'senha': 'SenhaForte@2024!', 'confirmacao': 'SenhaForte@2024!'},
        )

        assert resposta.status_code == 200
        assert 'Conta criada' in resposta.text
        assert User.objects.get(email='ana@email.com').check_password('SenhaForte@2024!')
        with schema_context(tenant.schema_name):
            assert ConviteColaborador.objects.get(pk=convite.pk).aceito

    def test_senhas_diferentes_nao_criam_conta(self, navegador, convite):
        resposta = navegador.post(
            f'/convite/{convite.token}', {'senha': 'SenhaForte@2024!', 'confirmacao': 'OutraSenha@2024!'},
        )

        assert resposta.status_code == 400
        assert 'As senhas não conferem.' in resposta.text
        assert not User.objects.filter(email='ana@email.com').exists()

    def test_senha_fraca_mostra_o_motivo(self, navegador, convite):
        resposta = navegador.post(f'/convite/{convite.token}', {'senha': '123', 'confirmacao': '123'})

        assert resposta.status_code == 400
        assert 'class="erro"' in resposta.text
        assert not User.objects.filter(email='ana@email.com').exists()

    def test_convite_ja_aceito_nao_abre_o_formulario(self, navegador, convite, tenant):
        with schema_context(tenant.schema_name):
            ConviteColaborador.objects.filter(pk=convite.pk).update(aceito=True)

        resposta = navegador.get(f'/convite/{convite.token}')

        assert resposta.status_code == 404
        assert '<form' not in resposta.text


@pytest.mark.django_db
class TestPaginaContrato:
    @pytest.fixture
    def contrato(self, tenant):
        cliente = Cliente.objects.create(nome='Ana', telefone='11999990000', email='ana@x.com')
        return Contrato.objects.create(
            cliente=cliente, titulo='Contrato de serviço', corpo='Cláusula 1.\nCláusula 2.',
            status=StatusContrato.ENVIADO,
        )

    def test_mostra_o_texto_e_o_formulario(self, navegador, contrato, tenant):
        resposta = navegador.get(f'/contrato/{tenant.schema_name}/{contrato.token}')

        assert resposta.status_code == 200
        assert 'Contrato de serviço' in resposta.text
        assert 'Cláusula 2.' in resposta.text
        assert 'Assinar contrato' in resposta.text

    def test_assinar_registra_nome_e_ip(self, navegador, contrato, tenant):
        url = f'/contrato/{tenant.schema_name}/{contrato.token}'
        resposta = navegador.post(
            url, {'acao': 'assinar', 'nome_assinante': 'Ana Souza'},
            REMOTE_ADDR='10.1.2.3', HTTP_X_FORWARDED_FOR='6.6.6.6',
        )

        assert resposta.status_code == 302
        assert resposta.url == url
        with schema_context(tenant.schema_name):
            contrato.refresh_from_db()
        assert contrato.status == StatusContrato.ASSINADO
        assert contrato.nome_assinante == 'Ana Souza'
        assert contrato.ip_assinante == '10.1.2.3'

    def test_assinar_sem_nome_nao_assina(self, navegador, contrato, tenant):
        resposta = navegador.post(
            f'/contrato/{tenant.schema_name}/{contrato.token}', {'acao': 'assinar', 'nome_assinante': ''},
        )

        assert resposta.status_code == 400
        with schema_context(tenant.schema_name):
            contrato.refresh_from_db()
        assert contrato.status == StatusContrato.ENVIADO

    def test_recusar(self, navegador, contrato, tenant):
        navegador.post(f'/contrato/{tenant.schema_name}/{contrato.token}', {'acao': 'recusar'})

        with schema_context(tenant.schema_name):
            contrato.refresh_from_db()
        assert contrato.status == StatusContrato.RECUSADO

    def test_contrato_assinado_nao_mostra_formulario(self, navegador, contrato, tenant):
        contrato.status = StatusContrato.ASSINADO
        contrato.nome_assinante = 'Ana'
        contrato.assinado_em = timezone.now()
        contrato.save()

        resposta = navegador.get(f'/contrato/{tenant.schema_name}/{contrato.token}')

        assert 'Assinado por Ana' in resposta.text
        assert '<form' not in resposta.text

    def test_schema_inexistente_retorna_404(self, navegador, contrato):
        resposta = navegador.get(f'/contrato/nao_existe/{contrato.token}')
        assert resposta.status_code == 404

    def test_schema_publico_nao_e_alvo(self, navegador, contrato):
        resposta = navegador.get(f'/contrato/public/{contrato.token}')
        assert resposta.status_code == 404


@pytest.mark.django_db
class TestPaginaPagamento:
    def test_mostra_o_codigo_da_assinatura(self, navegador):
        resposta = navegador.get('/app/pagamentos?preapproval_id=abc-123')

        assert resposta.status_code == 200
        assert 'abc-123' in resposta.text

    def test_sem_codigo(self, navegador):
        resposta = navegador.get('/app/pagamentos')

        assert resposta.status_code == 200
        assert 'Copiar código' not in resposta.text


@pytest.mark.django_db
class TestPrivacidade:
    def test_pagina_publica_com_o_responsavel_e_o_email(self, navegador, settings):
        settings.PRIVACIDADE_RESPONSAVEL = 'Fulano de Tal'
        settings.PRIVACIDADE_EMAIL = 'privacidade@exemplo.com'

        resposta = navegador.get('/privacidade')

        assert resposta.status_code == 200
        assert 'Fulano de Tal' in resposta.text
        assert 'mailto:privacidade@exemplo.com' in resposta.text
        assert 'Excluir conta' in resposta.text
        # a política é para ser achada: sem o noindex das outras páginas
        assert 'noindex' not in resposta.text
