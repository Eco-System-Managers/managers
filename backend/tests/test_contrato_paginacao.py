"""Paginação padrão das coleções (issue #6)."""
import pytest
from rest_framework.test import APIClient

from apps_work.servicos.models import Servico


@pytest.fixture
def api(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def trinta_servicos(patch_tenant_middleware):
    for i in range(30):
        Servico.objects.create(nome=f'Serviço {i:02d}', duracao=30, preco='10.00')


@pytest.mark.django_db
class TestPaginacaoPadrao:
    def test_formato(self, api, trinta_servicos):
        corpo = api.get('/api/v1/servicos/').json()
        assert set(corpo) == {'count', 'next', 'previous', 'results'}
        assert corpo['count'] == 30
        assert len(corpo['results']) == 20

    def test_page_size(self, api, trinta_servicos):
        corpo = api.get('/api/v1/servicos/?page_size=5').json()
        assert len(corpo['results']) == 5

    def test_page_size_tem_teto(self, api, trinta_servicos):
        for i in range(30, 130):
            Servico.objects.create(nome=f'Serviço {i}', duracao=30, preco='10.00')
        corpo = api.get('/api/v1/servicos/?page_size=1000').json()
        assert len(corpo['results']) == 100

    def test_segunda_pagina(self, api, trinta_servicos):
        corpo = api.get('/api/v1/servicos/?page=2').json()
        assert len(corpo['results']) == 10
        assert corpo['next'] is None

    def test_horarios_da_semana_sao_lista_fixa(self, api):
        resposta = api.get('/api/v1/empresa/horarios/')
        assert resposta.status_code == 200
        assert isinstance(resposta.json(), list)
