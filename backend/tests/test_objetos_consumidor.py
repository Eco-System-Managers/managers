"""Cadastro de pets e veículos do consumidor (ObjetoConsumidorService)."""
from unittest.mock import patch

import pytest
from django.db import connection
from django.test import override_settings
from django_tenants.middleware.main import TenantMainMiddleware
from rest_framework.test import APIClient

from apps_serv.autenticacao.authentication import gerar_tokens
from apps_serv.consumidores.models import ObjetoConsumidor
from apps_serv.consumidores.services import RegistroConsumidorService

URL = '/api/sm/v1/objetos/'


@pytest.fixture
def api(db):
    def _publico(_self, request):
        connection.set_schema_to_public()

    consumidor = RegistroConsumidorService().registrar(
        nome='Carla', email='carla@sm.com', senha='SenhaForte123!', telefone='11999990000',
    )
    access, _ = gerar_tokens(consumidor)
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {access}')
    with override_settings(ALLOWED_HOSTS=['*']):
        with patch.object(TenantMainMiddleware, 'process_request', _publico):
            yield client


@pytest.mark.django_db
class TestCadastroDeObjetos:
    def test_pet(self, api):
        resposta = api.post(URL, {'tipo': 'pet', 'dados': {'nome': 'Rex', 'especie': 'cão', 'porte': 'medio'}}, format='json')
        assert resposta.status_code == 201
        assert resposta.json()['nome_exibicao'] == 'Rex (cão)'

    def test_veiculo_grava_a_placa_normalizada(self, api):
        resposta = api.post(
            URL, {'tipo': 'veiculo', 'dados': {'placa': 'abc-1d23', 'marca': 'VW', 'modelo': 'Gol', 'porte': 'carro'}},
            format='json',
        )
        assert resposta.status_code == 201
        objeto = ObjetoConsumidor.objects.get()
        assert objeto.dados['placa'] == 'ABC1D23'
        assert objeto.nome_exibicao == 'VW Gol · ABC1D23'

    def test_placa_invalida_e_recusada(self, api):
        # Antes a validação existia mas nunca era chamada: qualquer placa passava.
        resposta = api.post(
            URL, {'tipo': 'veiculo', 'dados': {'placa': '1234', 'marca': 'VW', 'modelo': 'Gol', 'porte': 'carro'}},
            format='json',
        )
        assert resposta.status_code == 400
        assert resposta.json()['code'] == 'placa_invalida'
        assert not ObjetoConsumidor.objects.exists()

    def test_campos_obrigatorios(self, api):
        resposta = api.post(URL, {'tipo': 'pet', 'dados': {'nome': 'Rex'}}, format='json')
        assert resposta.status_code == 400
        assert resposta.json()['code'] == 'campos_obrigatorios'

    def test_tipo_invalido(self, api):
        resposta = api.post(URL, {'tipo': 'barco', 'dados': {}}, format='json')
        assert resposta.status_code == 400
        assert resposta.json()['code'] == 'tipo_invalido'

    def test_campos_desconhecidos_ficam_de_fora(self, api):
        dados = {'nome': 'Rex', 'especie': 'cão', 'porte': 'medio', 'senha': 'x'}
        resposta = api.post(URL, {'tipo': 'pet', 'dados': dados}, format='json')
        assert resposta.status_code == 201
        assert resposta.json()['dados'] == {'nome': 'Rex', 'especie': 'cão', 'porte': 'medio', 'raca': ''}

    def test_porte_pelo_rotulo_vira_o_valor_do_enum(self, api):
        dados = {'nome': 'Rex', 'especie': 'cão', 'porte': 'Médio'}
        resposta = api.post(URL, {'tipo': 'pet', 'dados': dados}, format='json')
        assert resposta.json()['dados']['porte'] == 'medio'

    def test_porte_invalido(self, api):
        dados = {'nome': 'Rex', 'especie': 'cão', 'porte': 'enorme'}
        resposta = api.post(URL, {'tipo': 'pet', 'dados': dados}, format='json')
        assert resposta.status_code == 400
        assert resposta.json()['code'] == 'porte_invalido'

    def test_veiculo_exige_o_porte(self, api):
        # O porte decide quais serviços servem para o veículo.
        resposta = api.post(
            URL, {'tipo': 'veiculo', 'dados': {'placa': 'ABC1D23', 'marca': 'VW', 'modelo': 'Gol'}}, format='json',
        )
        assert resposta.status_code == 400
        assert resposta.json()['code'] == 'campos_obrigatorios'

    def test_porte_de_pet_nao_serve_para_veiculo(self, api):
        dados = {'placa': 'ABC1D23', 'marca': 'VW', 'modelo': 'Gol', 'porte': 'grande'}
        resposta = api.post(URL, {'tipo': 'veiculo', 'dados': dados}, format='json')
        assert resposta.status_code == 400
        assert resposta.json()['code'] == 'porte_invalido'


@pytest.mark.parametrize('entrada, esperado', [
    ('medio', 'medio'), ('Médio', 'medio'), (' GRANDE ', 'grande'), ('enorme', ''), ('', ''), (None, ''),
])
def test_normalizar_porte(entrada, esperado):
    """A cópia do pet para o negócio só reconhecia 'médio' com acento: o valor
    do enum ('medio') chegava sem porte."""
    from apps_work.clientes.validators import normalizar_porte
    assert normalizar_porte(entrada) == esperado
