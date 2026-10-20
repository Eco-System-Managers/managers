import pytest
from datetime import date, datetime

from django.utils import timezone
from rest_framework.test import APIClient

from apps_work.agenda.models import Agendamento
from apps_work.agenda.services import DiasComRegistroService
from apps_work.clientes.models import Cliente
from apps_work.kanban.models import AtendimentoKanban, EtapaKanban
from apps_work.clientes.models import ObjetoCliente, Veiculo
from apps_work.servicos.models import Servico


@pytest.fixture
def client_autenticado(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


def _agendamento(dia: int, status: str = 'agendado') -> Agendamento:
    cliente = Cliente.objects.create(nome='Cliente', telefone='11999999999')
    return Agendamento.objects.create(
        cliente=cliente,
        data_hora=timezone.make_aware(datetime(2026, 6, dia, 10, 0)),
        status=status,
    )


def _atendimento_kanban(dia: int | None) -> AtendimentoKanban:
    cliente = Cliente.objects.create(nome='Dono', telefone='11988888888')
    veiculo = Veiculo.objects.create(cliente=cliente, tipo='veiculo', placa=f'ABC{dia or 0:04d}')
    servico = Servico.objects.create(nome='Lavagem', duracao=30, preco='50.00')
    etapa = EtapaKanban.objects.create(nome='Fila', ordem=0)
    return AtendimentoKanban.objects.create(
        etapa=etapa,
        objeto=ObjetoCliente.objects.get(pk=veiculo.pk),
        servico=servico,
        data=date(2026, 6, dia) if dia else None,
    )


@pytest.mark.django_db
class TestDiasComRegistroService:
    def test_sem_registros_retorna_lista_vazia(self, patch_tenant_middleware):
        assert DiasComRegistroService().listar(2026, 6) == []

    def test_agendamento_aparece_na_lista(self, patch_tenant_middleware):
        _agendamento(15)
        assert DiasComRegistroService().listar(2026, 6) == ['2026-06-15']

    def test_agendamento_cancelado_nao_aparece(self, patch_tenant_middleware):
        _agendamento(15, status='cancelado')
        assert DiasComRegistroService().listar(2026, 6) == []

    def test_atendimento_kanban_aparece_na_lista(self, patch_tenant_middleware):
        _atendimento_kanban(20)
        assert DiasComRegistroService().listar(2026, 6) == ['2026-06-20']

    def test_atendimento_kanban_sem_data_nao_aparece(self, patch_tenant_middleware):
        _atendimento_kanban(None)
        assert DiasComRegistroService().listar(2026, 6) == []

    def test_mes_diferente_nao_aparece(self, patch_tenant_middleware):
        _agendamento(15)
        assert DiasComRegistroService().listar(2026, 7) == []

    def test_dia_com_agendamento_e_kanban_aparece_uma_vez(self, patch_tenant_middleware):
        _agendamento(15)
        _atendimento_kanban(15)
        assert DiasComRegistroService().listar(2026, 6) == ['2026-06-15']

    def test_datas_vem_ordenadas(self, patch_tenant_middleware):
        _agendamento(20)
        _agendamento(5)
        assert DiasComRegistroService().listar(2026, 6) == ['2026-06-05', '2026-06-20']


@pytest.mark.django_db
class TestDiasComRegistroAPI:
    def test_retorna_200(self, client_autenticado):
        response = client_autenticado.get('/api/v1/agenda/dias-com-registro/?ano=2026&mes=6')
        assert response.status_code == 200

    def test_retorna_datas_do_mes(self, client_autenticado):
        _agendamento(15)
        response = client_autenticado.get('/api/v1/agenda/dias-com-registro/?ano=2026&mes=6')
        assert response.data == ['2026-06-15']

    def test_sem_parametros_retorna_400(self, client_autenticado):
        response = client_autenticado.get('/api/v1/agenda/dias-com-registro/')
        assert response.status_code == 400

    def test_parametro_nao_numerico_retorna_400(self, client_autenticado):
        response = client_autenticado.get('/api/v1/agenda/dias-com-registro/?ano=abc&mes=6')
        assert response.status_code == 400

    def test_mes_fora_do_intervalo_retorna_400(self, client_autenticado):
        response = client_autenticado.get('/api/v1/agenda/dias-com-registro/?ano=2026&mes=13')
        assert response.status_code == 400

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/v1/agenda/dias-com-registro/?ano=2026&mes=6')
        assert response.status_code == 401
