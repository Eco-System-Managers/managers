import pytest
from django.utils import timezone
from rest_framework.test import APIClient

from apps_work.agenda.models import Agendamento
from apps_work.clientes.models import Cliente


@pytest.fixture
def client_autenticado(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.mark.django_db
class TestRemocaoDeCliente:
    def test_cliente_manual_sem_atendimento_e_apagado(self, client_autenticado):
        cliente = Cliente.objects.create(nome='Ana', telefone='19999990000')

        response = client_autenticado.delete(f'/api/v1/clientes/{cliente.id}/')

        assert response.status_code == 204
        assert not Cliente.objects.filter(pk=cliente.pk).exists()

    def test_cliente_com_agendamento_nao_e_apagado(self, client_autenticado):
        """Agendamento protege o cliente: o histórico não pode ficar órfão.
        Antes o PROTECT do banco estourava em 500."""
        cliente = Cliente.objects.create(nome='Ana', telefone='19999990000')
        Agendamento.objects.create(cliente=cliente, data_hora=timezone.now())

        response = client_autenticado.delete(f'/api/v1/clientes/{cliente.id}/')

        assert response.status_code == 400
        assert response.data['code'] == 'cliente_com_atendimentos'
        assert Cliente.objects.filter(pk=cliente.pk).exists()
