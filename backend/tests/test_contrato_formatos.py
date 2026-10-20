"""Dinheiro como string e entradas inválidas que davam 500 ou resposta errada (issue #6)."""
import uuid
from datetime import date, timedelta

import pytest
from django.db import connection
from rest_framework.test import APIClient

from apps_serv.vitrine.models import NegocioPublico
from apps_work.clientes.models import Cliente
from apps_work.contratos.models import Contrato
from apps_work.servicos.models import Servico
from core.schemas import schema_valido


@pytest.fixture
def api(patch_tenant_middleware):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    return client


@pytest.fixture
def negocio_do_tenant(patch_tenant_middleware, tenant):
    """O tenant de teste publicado na vitrine, com um serviço."""
    Servico.objects.create(nome='Corte', duracao=30, preco='45.50')
    connection.set_schema_to_public()
    negocio = NegocioPublico.objects.create(
        schema_name=tenant.schema_name, nome='Empresa Teste', nicho='Barbearia',
        latitude='-23.55', longitude='-46.63', ativo=True,
    )
    connection.set_tenant(tenant)
    return negocio


@pytest.mark.django_db
class TestDinheiroNaVitrine:
    def test_preco_dos_servicos_sai_como_string(self, api, negocio_do_tenant):
        resposta = api.get(f'/api/sm/v1/negocios/{negocio_do_tenant.schema_name}/servicos/')
        assert resposta.status_code == 200
        servico = resposta.json()['results'][0]
        assert servico['preco'] == '45.50'
        assert isinstance(servico['taxa_cancelamento'], str)


@pytest.mark.django_db
class TestDisponibilidade:
    def test_id_nao_numerico_retorna_400_e_nao_500(self, api, negocio_do_tenant):
        amanha = (date.today() + timedelta(days=1)).isoformat()
        resposta = api.get(
            f'/api/sm/v1/negocios/{negocio_do_tenant.schema_name}/disponibilidade/',
            {'data': amanha, 'servico_id': 'abc'},
        )
        assert resposta.status_code == 400
        assert resposta.json()['code'] == 'parametros_invalidos'


@pytest.mark.django_db
class TestDespesasComDataInvalida:
    def test_data_invalida_retorna_400_e_nao_pagina_vazia(self, api, proprietario):
        api.force_authenticate(user=proprietario)
        resposta = api.get('/api/v1/financeiro/despesas/?data_inicio=31-12-2024')
        assert resposta.status_code == 400
        assert resposta.json()['code'] == 'data_invalida'


@pytest.mark.django_db
class TestContratoPublico:
    @pytest.fixture
    def contrato(self, patch_tenant_middleware):
        cliente = Cliente.objects.create(nome='Ana', telefone='11999990000')
        return Contrato.objects.create(cliente=cliente, titulo='Contrato', corpo='Corpo.')

    def test_contrato_valido(self, api, contrato, tenant):
        resposta = api.get(f'/api/v1/contratos/publico/{tenant.schema_name}/{contrato.token}/')
        assert resposta.status_code == 200

    def test_schema_inexistente_retorna_404_e_nao_500(self, api):
        resposta = api.get(f'/api/v1/contratos/publico/nao_existe/{uuid.uuid4()}/')
        assert resposta.status_code == 404

    def test_schema_publico_nao_e_alvo(self, api, contrato):
        resposta = api.get(f'/api/v1/contratos/publico/public/{contrato.token}/')
        assert resposta.status_code == 404


@pytest.mark.parametrize('schema, valido', [
    ('barbearia_ze', True),
    ('public', False),
    ('Barbearia', False),
    ('a;drop', False),
    ('', False),
    ('x' * 64, False),
])
def test_schema_valido(schema, valido):
    assert schema_valido(schema) is valido


# ---------------------------------------------------------------------------
# Correções apontadas na revisão do schema
# ---------------------------------------------------------------------------

@pytest.fixture
def api_dono(api, proprietario):
    api.force_authenticate(user=proprietario)
    return api


@pytest.mark.django_db
class TestDinheiroSempreComDuasCasas:
    def test_ticket_medio_do_caixa_sem_atendimentos(self, api_dono):
        hoje = date.today().isoformat()
        corpo = api_dono.get(f'/api/v1/financeiro/caixa/?data_inicio={hoje}&data_fim={hoje}').json()
        assert corpo['kpis']['ticket_medio'] == '0.00'

    def test_ticket_medio_do_dashboard_sem_atendimentos(self, api_dono):
        corpo = api_dono.get('/api/v1/dashboard/resumo/').json()
        assert corpo['kpis']['ticket_medio'] == '0.00'


@pytest.mark.django_db
def test_hora_do_dashboard_e_a_local(api_dono):
    from datetime import datetime, time
    from django.utils import timezone
    from apps_work.agenda.models import Agendamento

    cliente = Cliente.objects.create(nome='Ana', telefone='11999990000')
    # 10:30 em São Paulo = 13:30 em UTC, que é como fica no banco.
    local = timezone.make_aware(datetime.combine(timezone.localdate(), time(10, 30)))
    Agendamento.objects.create(cliente=cliente, data_hora=local, status='agendado')

    corpo = api_dono.get('/api/v1/dashboard/resumo/').json()
    assert [a['hora'] for a in corpo['agendamentos_hoje']] == ['10:30']


@pytest.mark.django_db
def test_ip_da_assinatura_ignora_x_forwarded_for(api, tenant):
    cliente = Cliente.objects.create(nome='Ana', telefone='11999990000', email='ana@x.com')
    contrato = Contrato.objects.create(
        cliente=cliente, titulo='Contrato', corpo='Corpo.', status=Contrato.STATUS_ENVIADO,
    )
    resposta = api.post(
        f'/api/v1/contratos/publico/{tenant.schema_name}/{contrato.token}/',
        {'acao': 'assinar', 'nome_assinante': 'Ana'},
        REMOTE_ADDR='10.1.2.3', HTTP_X_FORWARDED_FOR='6.6.6.6',
    )
    assert resposta.status_code == 200
    contrato.refresh_from_db()
    assert contrato.ip_assinante == '10.1.2.3'


@pytest.mark.django_db
def test_nova_senha_do_b2c_parecida_com_o_email_e_recusada():
    from apps_serv.consumidores.models import CodigoRecuperacaoConsumidor
    from apps_serv.consumidores.services import RecuperacaoSenhaConsumidorService, RegistroConsumidorService
    from core.excecoes import ErroDeNegocio

    consumidor = RegistroConsumidorService().registrar(
        nome='Carla', email='carla.souza@sm.com', senha='SenhaForte123!', telefone='11999990000',
    )
    registro, _ = CodigoRecuperacaoConsumidor.emitir(consumidor, '12345678')

    with pytest.raises(ErroDeNegocio) as info:
        RecuperacaoSenhaConsumidorService().redefinir_senha('carla.souza@sm.com', '12345678', 'carla.souza@sm.com')

    assert info.value.code == 'senha_fraca'
    registro.refresh_from_db()
    assert registro.tentativas == 0
