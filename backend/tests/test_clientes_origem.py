import pytest
from unittest.mock import patch

from rest_framework.test import APIClient

from apps_serv.consumidores.models import VinculoConsumidor
from apps_serv.consumidores.services import RegistroConsumidorService
from apps_work.clientes.models import Cliente
from apps_work.clientes.services import RemocaoClienteService


@pytest.fixture
def client_autenticado(patch_tenant_middleware, usuario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=usuario)
    return client


@pytest.fixture
def consumidor(db):
    return RegistroConsumidorService().registrar(
        nome='Carlos Cliente',
        email='carlos@sm.com',
        senha='SenhaForte123!',
    )


@pytest.mark.django_db
class TestOrigemPadrao:
    def test_cliente_novo_nasce_manual(self, patch_tenant_middleware):
        cliente = Cliente.objects.create(nome='Maria', telefone='11999999999')
        assert cliente.origem == Cliente.ORIGEM_MANUAL

    def test_cadastro_pela_api_nasce_manual(self, client_autenticado):
        response = client_autenticado.post(
            '/api/clientes/', {'nome': 'Joana', 'telefone': '11988887777'}, format='json'
        )
        assert response.status_code == 201
        assert response.data['origem'] == 'manual'

    def test_origem_nao_pode_ser_definida_pela_api(self, client_autenticado):
        """Só quem cria o cadastro decide a origem — nunca o cliente da API."""
        response = client_autenticado.post(
            '/api/clientes/',
            {'nome': 'Joana', 'telefone': '11988887777', 'origem': 'servicemanage'},
            format='json',
        )
        assert response.data['origem'] == 'manual'


@pytest.mark.django_db
class TestRemocaoCliente:
    def test_cliente_manual_e_apagado(self, patch_tenant_middleware):
        cliente = Cliente.objects.create(nome='Maria', origem=Cliente.ORIGEM_MANUAL)
        RemocaoClienteService().remover(cliente)
        assert not Cliente.objects.filter(pk=cliente.pk).exists()

    def test_cliente_do_servicemanage_nao_e_apagado(self, patch_tenant_middleware):
        cliente = Cliente.objects.create(nome='Carlos', origem=Cliente.ORIGEM_SERVICEMANAGE)
        RemocaoClienteService().remover(cliente)
        assert Cliente.objects.filter(pk=cliente.pk).exists()

    def test_cliente_do_servicemanage_e_arquivado(self, patch_tenant_middleware):
        cliente = Cliente.objects.create(nome='Carlos', origem=Cliente.ORIGEM_SERVICEMANAGE)
        RemocaoClienteService().remover(cliente)
        cliente.refresh_from_db()
        assert cliente.visivel is False

    def test_cliente_arquivado_some_da_listagem(self, client_autenticado):
        cliente = Cliente.objects.create(nome='Carlos', origem=Cliente.ORIGEM_SERVICEMANAGE)
        client_autenticado.delete(f'/api/clientes/{cliente.pk}/')
        response = client_autenticado.get('/api/clientes/')
        assert all(c['id'] != cliente.pk for c in response.data['results'])

    def test_remocao_do_servicemanage_emite_sinal(self, patch_tenant_middleware):
        cliente = Cliente.objects.create(
            nome='Carlos', email='carlos@sm.com', origem=Cliente.ORIGEM_SERVICEMANAGE
        )
        with patch('apps_work.clientes.services.cliente_servicemanage_removido') as sinal:
            RemocaoClienteService().remover(cliente)
        assert sinal.send.called

    def test_remocao_manual_nao_emite_sinal(self, patch_tenant_middleware):
        cliente = Cliente.objects.create(nome='Maria', origem=Cliente.ORIGEM_MANUAL)
        with patch('apps_work.clientes.services.cliente_servicemanage_removido') as sinal:
            RemocaoClienteService().remover(cliente)
        assert not sinal.send.called


@pytest.mark.django_db
class TestVinculoDesfeitoNaRemocao:
    def test_vinculo_fica_inativo(self, patch_tenant_middleware, consumidor, tenant):
        VinculoConsumidor.objects.create(consumidor=consumidor, schema_name=tenant.schema_name)
        cliente = Cliente.objects.create(
            nome='Carlos', email=consumidor.email, origem=Cliente.ORIGEM_SERVICEMANAGE
        )

        RemocaoClienteService().remover(cliente)

        vinculo = VinculoConsumidor.objects.get(consumidor=consumidor, schema_name=tenant.schema_name)
        assert vinculo.ativo is False

    def test_vinculo_registra_data_da_desvinculacao(self, patch_tenant_middleware, consumidor, tenant):
        VinculoConsumidor.objects.create(consumidor=consumidor, schema_name=tenant.schema_name)
        cliente = Cliente.objects.create(
            nome='Carlos', email=consumidor.email, origem=Cliente.ORIGEM_SERVICEMANAGE
        )

        RemocaoClienteService().remover(cliente)

        vinculo = VinculoConsumidor.objects.get(consumidor=consumidor, schema_name=tenant.schema_name)
        assert vinculo.desvinculado_em is not None

    def test_vinculo_de_outro_negocio_nao_e_afetado(self, patch_tenant_middleware, consumidor, tenant):
        VinculoConsumidor.objects.create(consumidor=consumidor, schema_name='outro_negocio')
        cliente = Cliente.objects.create(
            nome='Carlos', email=consumidor.email, origem=Cliente.ORIGEM_SERVICEMANAGE
        )

        RemocaoClienteService().remover(cliente)

        outro = VinculoConsumidor.objects.get(consumidor=consumidor, schema_name='outro_negocio')
        assert outro.ativo is True

    def test_remocao_de_cliente_manual_nao_mexe_no_vinculo(self, patch_tenant_middleware, consumidor, tenant):
        VinculoConsumidor.objects.create(consumidor=consumidor, schema_name=tenant.schema_name)
        cliente = Cliente.objects.create(
            nome='Carlos', email=consumidor.email, origem=Cliente.ORIGEM_MANUAL
        )

        RemocaoClienteService().remover(cliente)

        vinculo = VinculoConsumidor.objects.get(consumidor=consumidor, schema_name=tenant.schema_name)
        assert vinculo.ativo is True
