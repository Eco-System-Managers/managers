import pytest
from rest_framework.test import APIClient

from apps_work.clientes.models import Cliente
from apps_work.contratos.models import Contrato


@pytest.fixture
def client_autenticado(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def cliente(patch_tenant_middleware):
    return Cliente.objects.create(nome='Ana Lima', telefone='11999990000')


def _contrato(cliente, titulo='Contrato', status=Contrato.STATUS_PENDENTE):
    return Contrato.objects.create(
        cliente=cliente, titulo=titulo, corpo='Corpo do contrato.', status=status,
    )


@pytest.mark.django_db
class TestContratoAPI:
    URL = '/api/contratos/'

    def test_listar_retorna_200(self, client_autenticado, cliente):
        _contrato(cliente)
        assert client_autenticado.get(self.URL).status_code == 200

    def test_listagem_vem_paginada(self, client_autenticado, cliente):
        _contrato(cliente)
        response = client_autenticado.get(self.URL)
        assert set(response.data) >= {'count', 'next', 'previous', 'results'}

    def test_pagina_traz_no_maximo_vinte(self, client_autenticado, cliente):
        for i in range(25):
            _contrato(cliente, titulo=f'Contrato {i:02d}')
        response = client_autenticado.get(self.URL)
        assert response.data['count'] == 25
        assert len(response.data['results']) == 20
        assert response.data['next'] is not None

    def test_segunda_pagina_traz_o_restante(self, client_autenticado, cliente):
        for i in range(25):
            _contrato(cliente, titulo=f'Contrato {i:02d}')
        response = client_autenticado.get(f'{self.URL}?page=2')
        assert len(response.data['results']) == 5
        assert response.data['next'] is None

    def test_paginas_nao_repetem_contrato(self, client_autenticado, cliente):
        """Contratos criados no mesmo instante precisam de desempate estavel,
        senao o mesmo registro cai em duas paginas e outro some."""
        for i in range(25):
            _contrato(cliente, titulo=f'Contrato {i:02d}')
        p1 = client_autenticado.get(self.URL).data['results']
        p2 = client_autenticado.get(f'{self.URL}?page=2').data['results']
        ids = [c['id'] for c in p1] + [c['id'] for c in p2]
        assert len(ids) == len(set(ids)) == 25

    def test_filtra_por_status(self, client_autenticado, cliente):
        _contrato(cliente, titulo='Pendente', status=Contrato.STATUS_PENDENTE)
        _contrato(cliente, titulo='Assinado', status=Contrato.STATUS_ASSINADO)
        response = client_autenticado.get(f'{self.URL}?status=assinado')
        assert response.data['count'] == 1
        assert response.data['results'][0]['titulo'] == 'Assinado'

    def test_filtra_por_cliente(self, client_autenticado, cliente):
        outro = Cliente.objects.create(nome='Bruno Reis', telefone='11888880000')
        _contrato(cliente, titulo='Do Ana')
        _contrato(outro, titulo='Do Bruno')
        response = client_autenticado.get(f'{self.URL}?cliente={cliente.id}')
        assert response.data['count'] == 1
        assert response.data['results'][0]['titulo'] == 'Do Ana'

    def test_filtro_pagina_o_proprio_resultado(self, client_autenticado, cliente):
        for i in range(25):
            _contrato(cliente, titulo=f'Assinado {i:02d}', status=Contrato.STATUS_ASSINADO)
        _contrato(cliente, titulo='Fora do filtro', status=Contrato.STATUS_PENDENTE)
        response = client_autenticado.get(f'{self.URL}?status=assinado')
        assert response.data['count'] == 25
        assert len(response.data['results']) == 20

    def test_sem_auth_retorna_401(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        assert client.get(self.URL).status_code == 401
