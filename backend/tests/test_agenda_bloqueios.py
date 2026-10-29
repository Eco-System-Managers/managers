"""Bloqueios da agenda: o que tiram da grade, quem pode criar e o impedimento
de bloquear em cima de cliente."""
from datetime import datetime, time, timedelta

import pytest
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APIClient

from apps_work.agenda.models import Agendamento, AgendamentoServico, Bloqueio
from apps_work.agenda.services import SlotsAgendaService
from apps_work.clientes.models import Cliente
from apps_work.empresa.models import HorarioFuncionamento
from apps_work.servicos.models import Servico
from apps_work.usuarios.models import Colaborador
from tenants.models import Membro

URL = '/api/v1/agenda/bloqueios/'

# Uma semana à frente: o bloqueio começa hoje ou depois, e o impedimento só
# olha atendimento que ainda vai acontecer.
DIA = timezone.localdate() + timedelta(days=7)


def _client(user):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=user)
    return client


def _membro(tenant, email, tipo):
    user = User.objects.create_user(username=email, email=email, password='SenhaForte123!')
    Membro.objects.create(user=user, tenant=tenant, papel='colaborador')
    return Colaborador.objects.create(user=user, nome=email, tipo=tipo)


@pytest.fixture
def expediente(patch_tenant_middleware):
    for dia in range(7):
        HorarioFuncionamento.objects.update_or_create(
            dia=dia, defaults={'abertura': time(9, 0), 'fechamento': time(14, 0), 'ativo': True},
        )


@pytest.fixture
def servico(patch_tenant_middleware):
    return Servico.objects.create(nome='Corte', duracao=60, preco='50.00')


@pytest.fixture
def dono(patch_tenant_middleware, proprietario):
    Colaborador.objects.create(user=proprietario, nome='Dono')
    return _client(proprietario)


@pytest.fixture
def leo(patch_tenant_middleware, tenant):
    return _membro(tenant, 'leo@x.com', 'parceiro')


@pytest.fixture
def joao(patch_tenant_middleware, tenant):
    return _membro(tenant, 'joao@x.com', 'colaborador')


def _agendar(colaborador, servico, dia, hora: time, status='agendado') -> Agendamento:
    cliente = Cliente.objects.create(nome='Ana', telefone='11999999999')
    ag = Agendamento.objects.create(
        cliente=cliente, colaborador=colaborador, status=status,
        data_hora=timezone.make_aware(datetime.combine(dia, hora)),
    )
    AgendamentoServico.objects.create(agendamento=ag, servico=servico, preco_cobrado='50.00')
    return ag


def _horarios(colaborador, dia, duracao=60) -> list[str]:
    return [i.strftime('%H:%M') for i in SlotsAgendaService().livres(dia, colaborador.pk, duracao)]


@pytest.mark.django_db
class TestBloqueioNaGrade:
    def test_horario_bloqueado_some_da_grade(self, expediente, leo):
        Bloqueio.objects.create(colaborador=leo, data_inicio=DIA, data_fim=DIA, hora_inicio=time(12, 0), hora_fim=time(13, 0))

        horarios = _horarios(leo, DIA)

        assert '11:00' in horarios  # termina às 12:00, encostando no bloqueio
        assert '11:15' not in horarios
        assert '12:00' not in horarios
        assert '13:00' in horarios

    def test_fixo_vale_nos_dias_seguintes(self, expediente, leo):
        Bloqueio.objects.create(colaborador=leo, data_inicio=DIA, hora_inicio=time(12, 0), hora_fim=time(13, 0))

        assert '12:00' not in _horarios(leo, DIA + timedelta(days=20))

    def test_periodo_acaba_na_data_fim(self, expediente, leo):
        Bloqueio.objects.create(colaborador=leo, data_inicio=DIA, data_fim=DIA, hora_inicio=time(12, 0), hora_fim=time(13, 0))

        assert '12:00' in _horarios(leo, DIA + timedelta(days=1))

    def test_dia_inteiro_tira_a_grade_toda(self, expediente, leo):
        Bloqueio.objects.create(colaborador=leo, data_inicio=DIA, data_fim=DIA + timedelta(days=6))

        assert _horarios(leo, DIA + timedelta(days=3)) == []

    def test_bloqueio_de_um_nao_afeta_o_outro(self, expediente, leo, joao):
        Bloqueio.objects.create(colaborador=leo, data_inicio=DIA, data_fim=DIA)

        assert '12:00' in _horarios(joao, DIA)


@pytest.mark.django_db
class TestQuemPodeBloquear:
    def _payload(self, colaborador, **extra):
        return {
            'colaborador': colaborador.pk, 'data_inicio': DIA.isoformat(), 'data_fim': DIA.isoformat(),
            'hora_inicio': '12:00', 'hora_fim': '13:00', **extra,
        }

    def test_dono_bloqueia_a_agenda_de_qualquer_um(self, dono, leo, joao):
        assert dono.post(URL, self._payload(leo), format='json').status_code == 201
        assert dono.post(URL, self._payload(joao), format='json').status_code == 201

    def test_parceiro_bloqueia_a_propria_agenda(self, leo):
        response = _client(leo.user).post(URL, self._payload(leo), format='json')

        assert response.status_code == 201
        assert response.json()['colaborador_nome'] == 'leo@x.com'

    def test_parceiro_nao_bloqueia_a_agenda_dos_outros(self, leo, joao):
        response = _client(leo.user).post(URL, self._payload(joao), format='json')

        assert response.status_code == 403
        assert response.json()['code'] == 'sem_permissao_bloquear'

    def test_colaborador_nao_bloqueia(self, joao):
        response = _client(joao.user).post(URL, self._payload(joao), format='json')

        assert response.status_code == 403
        assert response.json()['code'] == 'sem_permissao_bloquear'

    def test_colaborador_ve_os_bloqueios(self, dono, leo, joao):
        dono.post(URL, self._payload(joao), format='json')

        response = _client(joao.user).get(URL, {'data': DIA.isoformat()})

        assert response.status_code == 200
        assert response.json()['count'] == 1

    def test_parceiro_so_exclui_o_proprio(self, dono, leo, joao):
        do_joao = dono.post(URL, self._payload(joao), format='json').json()
        do_leo = dono.post(URL, self._payload(leo), format='json').json()
        api = _client(leo.user)

        assert api.delete(f'{URL}{do_joao["id"]}/').status_code == 403
        assert api.delete(f'{URL}{do_leo["id"]}/').status_code == 204

    def test_nao_edita(self, dono, leo):
        criado = dono.post(URL, self._payload(leo), format='json').json()

        response = dono.patch(f'{URL}{criado["id"]}/', {'motivo': 'Almoço'}, format='json')

        assert response.status_code == 405


@pytest.mark.django_db
class TestBloqueioSobreCliente:
    def _bloquear(self, dono, colaborador, **campos):
        payload = {'colaborador': colaborador.pk, 'data_inicio': DIA.isoformat(), **campos}
        return dono.post(URL, payload, format='json')

    def test_horario_com_cliente_e_recusado(self, dono, leo, servico):
        _agendar(leo, servico, DIA, time(12, 30))

        response = self._bloquear(dono, leo, data_fim=DIA.isoformat(), hora_inicio='12:00', hora_fim='13:00')

        assert response.status_code == 400
        assert response.json()['code'] == 'bloqueio_com_cliente'
        assert not Bloqueio.objects.exists()

    def test_atendimento_que_encosta_nao_impede(self, dono, leo, servico):
        _agendar(leo, servico, DIA, time(11, 0))  # termina às 12:00

        response = self._bloquear(dono, leo, data_fim=DIA.isoformat(), hora_inicio='12:00', hora_fim='13:00')

        assert response.status_code == 201

    def test_fixo_olha_as_semanas_seguintes(self, dono, leo, servico):
        _agendar(leo, servico, DIA + timedelta(days=14), time(12, 0))

        response = self._bloquear(dono, leo, hora_inicio='12:00', hora_fim='13:00')

        assert response.json()['code'] == 'bloqueio_com_cliente'

    def test_dia_inteiro_com_cliente_e_recusado(self, dono, leo, servico):
        _agendar(leo, servico, DIA, time(9, 0))

        response = self._bloquear(dono, leo, data_fim=DIA.isoformat())

        assert response.json()['code'] == 'bloqueio_com_cliente'

    @pytest.mark.parametrize('status', ['cancelado', 'faltou', 'concluido'])
    def test_atendimento_com_desfecho_nao_impede(self, dono, leo, servico, status):
        _agendar(leo, servico, DIA, time(12, 0), status=status)

        response = self._bloquear(dono, leo, data_fim=DIA.isoformat(), hora_inicio='12:00', hora_fim='13:00')

        assert response.status_code == 201

    def test_cliente_de_outro_profissional_nao_impede(self, dono, leo, joao, servico):
        _agendar(joao, servico, DIA, time(12, 0))

        response = self._bloquear(dono, leo, data_fim=DIA.isoformat(), hora_inicio='12:00', hora_fim='13:00')

        assert response.status_code == 201


@pytest.mark.django_db
class TestEmpresaNaoMarcaEmCimaDoBloqueio:
    def test_marcar_em_cima_do_bloqueio_e_recusado(self, dono, leo, servico):
        Bloqueio.objects.create(colaborador=leo, data_inicio=DIA, hora_inicio=time(12, 0), hora_fim=time(13, 0))
        cliente = Cliente.objects.create(nome='Ana', telefone='11999999999')
        quando = timezone.make_aware(datetime.combine(DIA, time(11, 30)))

        response = dono.post('/api/v1/agendamentos/', {
            'cliente': cliente.pk, 'colaborador': leo.pk, 'servico_id': servico.pk, 'data_hora': quando.isoformat(),
        }, format='json')

        assert response.status_code == 400
        assert response.json()['code'] == 'horario_bloqueado'

    def test_remarcar_para_dentro_do_bloqueio_e_recusado(self, dono, leo, servico):
        ag = _agendar(leo, servico, DIA, time(9, 0))
        Bloqueio.objects.create(colaborador=leo, data_inicio=DIA, hora_inicio=time(12, 0), hora_fim=time(13, 0))
        quando = timezone.make_aware(datetime.combine(DIA, time(12, 0)))

        response = dono.patch(f'/api/v1/agendamentos/{ag.pk}/', {'data_hora': quando.isoformat()}, format='json')

        assert response.json()['code'] == 'horario_bloqueado'


@pytest.mark.django_db
class TestValidacaoDoBloqueio:
    def test_so_uma_das_horas_e_recusado(self, dono, leo):
        response = dono.post(URL, {'colaborador': leo.pk, 'data_inicio': DIA.isoformat(), 'hora_inicio': '12:00'}, format='json')

        assert response.status_code == 400
        assert 'hora_fim' in response.json()['fields']

    def test_fim_antes_do_inicio_e_recusado(self, dono, leo):
        response = dono.post(URL, {
            'colaborador': leo.pk, 'data_inicio': DIA.isoformat(), 'hora_inicio': '13:00', 'hora_fim': '12:00',
        }, format='json')

        assert 'hora_fim' in response.json()['fields']

    def test_comecar_no_passado_e_recusado(self, dono, leo):
        ontem = timezone.localdate() - timedelta(days=1)

        response = dono.post(URL, {'colaborador': leo.pk, 'data_inicio': ontem.isoformat()}, format='json')

        assert 'data_inicio' in response.json()['fields']

    def test_listar_por_dia_traz_o_fixo(self, dono, leo):
        Bloqueio.objects.create(colaborador=leo, data_inicio=DIA, hora_inicio=time(12, 0), hora_fim=time(13, 0))
        Bloqueio.objects.create(colaborador=leo, data_inicio=DIA, data_fim=DIA, hora_inicio=time(9, 0), hora_fim=time(10, 0))

        response = dono.get(URL, {'data': (DIA + timedelta(days=30)).isoformat()})

        assert response.json()['count'] == 1
