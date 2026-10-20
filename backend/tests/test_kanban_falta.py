import pytest
from datetime import date

from django.utils import timezone
from rest_framework.test import APIClient

from apps_serv.consumidores.models import AgendamentoConsumidor
from apps_serv.consumidores.services import RegistroConsumidorService
from apps_work.agenda.services import PendenciasCobrancaService
from apps_work.clientes.models import Cliente, ObjetoCliente, Veiculo
from apps_work.kanban.models import AtendimentoKanban, EtapaKanban
from apps_work.kanban.services import AtendimentoKanbanService
from apps_work.servicos.models import Servico

HOJE = date(2026, 6, 15)


@pytest.fixture
def client_autenticado(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def servico(patch_tenant_middleware):
    return Servico.objects.create(nome='Banho', duracao=60, preco='80.00')


@pytest.fixture
def atendimento(patch_tenant_middleware, servico):
    cliente = Cliente.objects.create(nome='Dono do Rex', telefone='11999999999')
    veiculo = Veiculo.objects.create(cliente=cliente, tipo='veiculo', placa='ABC1234')
    etapa = EtapaKanban.objects.create(nome='Aguardando', ordem=0)
    return AtendimentoKanban.objects.create(
        etapa=etapa,
        objeto=ObjetoCliente.objects.get(pk=veiculo.pk),
        servico=servico,
        data=date(2026, 6, 10),
    )


@pytest.fixture
def consumidor(db):
    return RegistroConsumidorService().registrar(
        nome='Dono do Rex', email='dono@sm.com', senha='SenhaForte123!',
    )


def _espelho(consumidor, tenant, atendimento):
    return AgendamentoConsumidor.objects.create(
        consumidor=consumidor,
        schema_name=tenant.schema_name,
        agendamento_id=atendimento.pk,
        origem='kanban',
        negocio_nome='Empresa Teste',
        data_hora=timezone.now(),
        duracao_total=60,
        valor_total='80.00',
        status='agendado',
    )


@pytest.mark.django_db
class TestMarcarFalta:
    def test_marcar_falta_grava_no_atendimento(self, atendimento):
        AtendimentoKanbanService().marcar_falta(atendimento)
        atendimento.refresh_from_db()
        assert atendimento.faltou is True

    def test_desfazer_falta_volta_ao_normal(self, atendimento):
        AtendimentoKanbanService().marcar_falta(atendimento)
        AtendimentoKanbanService().desfazer_falta(atendimento)
        atendimento.refresh_from_db()
        assert atendimento.faltou is False

    def test_atendimento_pago_recusa_falta(self, client_autenticado, atendimento):
        atendimento.pago = True
        atendimento.save(update_fields=['pago'])

        response = client_autenticado.post(f'/api/v1/kanban/atendimentos/{atendimento.pk}/marcar_falta/')

        assert response.status_code == 400

    def test_api_marca_falta(self, client_autenticado, atendimento):
        response = client_autenticado.post(f'/api/v1/kanban/atendimentos/{atendimento.pk}/marcar_falta/')
        assert response.data['faltou'] is True

    def test_api_desfaz_falta(self, client_autenticado, atendimento):
        client_autenticado.post(f'/api/v1/kanban/atendimentos/{atendimento.pk}/marcar_falta/')
        response = client_autenticado.post(f'/api/v1/kanban/atendimentos/{atendimento.pk}/desfazer_falta/')
        assert response.data['faltou'] is False


@pytest.mark.django_db
class TestFaltaSaiDasPendencias:
    def test_atendimento_com_falta_nao_e_pendencia(self, atendimento):
        AtendimentoKanbanService().marcar_falta(atendimento)
        assert PendenciasCobrancaService().listar(HOJE) == []

    def test_atendimento_sem_falta_continua_pendencia(self, atendimento):
        assert len(PendenciasCobrancaService().listar(HOJE)) == 1


@pytest.mark.django_db
class TestFaltaEspelhadaNoConsumidor:
    def test_falta_chega_no_app(self, client_autenticado, consumidor, tenant, atendimento):
        espelho = _espelho(consumidor, tenant, atendimento)

        client_autenticado.post(f'/api/v1/kanban/atendimentos/{atendimento.pk}/marcar_falta/')

        espelho.refresh_from_db()
        assert espelho.status == 'faltou'

    def test_desfazer_falta_devolve_o_atendimento_ao_app(self, client_autenticado, consumidor, tenant, atendimento):
        espelho = _espelho(consumidor, tenant, atendimento)
        client_autenticado.post(f'/api/v1/kanban/atendimentos/{atendimento.pk}/marcar_falta/')

        client_autenticado.post(f'/api/v1/kanban/atendimentos/{atendimento.pk}/desfazer_falta/')

        espelho.refresh_from_db()
        assert espelho.status == 'agendado'
