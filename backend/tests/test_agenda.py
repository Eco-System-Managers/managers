import pytest
from django.utils import timezone
from apps_work.clientes.models import Cliente
from apps_work.servicos.models import Servico
from apps_work.usuarios.models import Colaborador
from apps_work.agenda.models import Agendamento, AgendamentoServico


@pytest.fixture
def cliente(tenant):
    return Cliente.objects.create(nome='Ana Souza')


@pytest.fixture
def servico(tenant):
    return Servico.objects.create(nome='Corte', duracao=30, preco='50.00')


@pytest.fixture
def colaborador(tenant, usuario):
    return Colaborador.objects.create(user=usuario)


@pytest.mark.django_db
class TestAgendamentoModel:
    def test_criar_agendamento(self, cliente):
        agendamento = Agendamento.objects.create(
            cliente=cliente,
            data_hora=timezone.now(),
        )
        assert agendamento.id is not None
        assert agendamento.cliente == cliente

    def test_str_agendamento(self, cliente):
        data_hora = timezone.now()
        agendamento = Agendamento.objects.create(cliente=cliente, data_hora=data_hora)
        assert str(agendamento) == f'{cliente} — {data_hora:%d/%m/%Y %H:%M}'

    def test_status_padrao(self, cliente):
        agendamento = Agendamento.objects.create(cliente=cliente, data_hora=timezone.now())
        assert agendamento.status == 'agendado'


@pytest.mark.django_db
class TestAgendamentoServicoModel:
    def test_criar_agendamento_servico(self, cliente, servico):
        agendamento = Agendamento.objects.create(cliente=cliente, data_hora=timezone.now())
        ag_servico = AgendamentoServico.objects.create(
            agendamento=agendamento,
            servico=servico,
            preco_cobrado='50.00',
        )
        assert ag_servico.id is not None
        assert ag_servico.agendamento == agendamento
        assert ag_servico.servico == servico
