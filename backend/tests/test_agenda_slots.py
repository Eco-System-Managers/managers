import pytest
from datetime import date, datetime, time

from django.utils import timezone
from rest_framework.test import APIClient

from apps_work.agenda.models import Agendamento, AgendamentoServico
from apps_work.agenda.services import SlotsAgendaService
from apps_work.clientes.models import Cliente
from apps_work.empresa.models import HorarioFuncionamento
from apps_work.servicos.models import Servico
from apps_work.usuarios.models import Colaborador

# Quarta-feira: weekday() == 2.
DIA = date(2026, 6, 10)


@pytest.fixture
def client_autenticado(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def expediente(patch_tenant_middleware):
    HorarioFuncionamento.objects.update_or_create(
        dia=DIA.weekday(),
        defaults={'abertura': time(9, 0), 'fechamento': time(12, 0), 'ativo': True},
    )


@pytest.fixture
def servico(patch_tenant_middleware):
    return Servico.objects.create(nome='Corte', duracao=60, preco='50.00')


@pytest.fixture
def colaborador(patch_tenant_middleware, usuario):
    return Colaborador.objects.create(user=usuario)


@pytest.fixture
def outro_colaborador(patch_tenant_middleware, django_user_model):
    outro = django_user_model.objects.create_user(
        username='outro@email.com', email='outro@email.com', password='senha123',
    )
    return Colaborador.objects.create(user=outro)


def _agendar(colaborador, servico, hora: time, nome='Ocupa') -> Agendamento:
    cliente = Cliente.objects.create(nome=nome, telefone='11999999999')
    ag = Agendamento.objects.create(
        cliente=cliente,
        colaborador=colaborador,
        data_hora=timezone.make_aware(datetime.combine(DIA, hora)),
        status='agendado',
    )
    AgendamentoServico.objects.create(agendamento=ag, servico=servico, preco_cobrado='50.00')
    return ag


@pytest.mark.django_db
class TestGradeDeSlots:
    def test_grade_cobre_o_expediente_de_meia_em_meia_hora(self, expediente, servico, colaborador):
        slots = SlotsAgendaService().listar(DIA, servico.pk, colaborador.pk)
        assert [s['horario'] for s in slots] == ['09:00', '09:30', '10:00', '10:30', '11:00']

    def test_dia_sem_expediente_nao_tem_grade(self, patch_tenant_middleware, servico, colaborador):
        assert SlotsAgendaService().listar(DIA, servico.pk, colaborador.pk) == []

    def test_horario_ocupado_fica_indisponivel(self, expediente, servico, colaborador):
        _agendar(colaborador, servico, time(10, 0))

        slots = SlotsAgendaService().listar(DIA, servico.pk, colaborador.pk)

        assert [s['horario'] for s in slots if not s['disponivel']] == ['09:30', '10:00', '10:30']

    def test_agenda_de_outro_colaborador_nao_afeta(self, expediente, servico, colaborador, outro_colaborador):
        _agendar(outro_colaborador, servico, time(10, 0))

        slots = SlotsAgendaService().listar(DIA, servico.pk, colaborador.pk)

        assert all(s['disponivel'] for s in slots)

    def test_agendamento_cancelado_libera_o_horario(self, expediente, servico, colaborador):
        ag = _agendar(colaborador, servico, time(10, 0))
        ag.status = 'cancelado'
        ag.save(update_fields=['status'])

        slots = SlotsAgendaService().listar(DIA, servico.pk, colaborador.pk)

        assert all(s['disponivel'] for s in slots)


@pytest.mark.django_db
class TestSlotsAPI:
    def test_retorna_a_grade(self, client_autenticado, expediente, servico, colaborador):
        response = client_autenticado.get(
            f'/api/agenda/slots/?data={DIA.isoformat()}&servico={servico.pk}&colaborador={colaborador.pk}'
        )
        assert response.status_code == 200

    def test_sem_colaborador_recusa(self, client_autenticado, expediente, servico):
        response = client_autenticado.get(
            f'/api/agenda/slots/?data={DIA.isoformat()}&servico={servico.pk}'
        )
        assert response.status_code == 400

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/agenda/slots/')
        assert response.status_code == 401
