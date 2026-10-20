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
        resposta = api.get(f'/api/sm/negocios/{negocio_do_tenant.schema_name}/servicos/')
        assert resposta.status_code == 200
        servico = resposta.json()['results'][0]
        assert servico['preco'] == '45.50'
        assert isinstance(servico['taxa_cancelamento'], str)


@pytest.mark.django_db
class TestDisponibilidade:
    def test_id_nao_numerico_retorna_400_e_nao_500(self, api, negocio_do_tenant):
        amanha = (date.today() + timedelta(days=1)).isoformat()
        resposta = api.get(
            f'/api/sm/negocios/{negocio_do_tenant.schema_name}/disponibilidade/',
            {'data': amanha, 'servico_id': 'abc'},
        )
        assert resposta.status_code == 400
        assert resposta.json()['code'] == 'parametros_invalidos'


@pytest.mark.django_db
class TestDespesasComDataInvalida:
    def test_data_invalida_retorna_400_e_nao_pagina_vazia(self, api, proprietario):
        api.force_authenticate(user=proprietario)
        resposta = api.get('/api/financeiro/despesas/?data_inicio=31-12-2024')
        assert resposta.status_code == 400
        assert resposta.json()['code'] == 'data_invalida'


@pytest.mark.django_db
class TestContratoPublico:
    @pytest.fixture
    def contrato(self, patch_tenant_middleware):
        cliente = Cliente.objects.create(nome='Ana', telefone='11999990000')
        return Contrato.objects.create(cliente=cliente, titulo='Contrato', corpo='Corpo.')

    def test_contrato_valido(self, api, contrato, tenant):
        resposta = api.get(f'/contratos/{tenant.schema_name}/{contrato.token}/')
        assert resposta.status_code == 200

    def test_schema_inexistente_retorna_404_e_nao_500(self, api):
        resposta = api.get(f'/contratos/nao_existe/{uuid.uuid4()}/')
        assert resposta.status_code == 404

    def test_schema_publico_nao_e_alvo(self, api, contrato):
        resposta = api.get(f'/contratos/public/{contrato.token}/')
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
