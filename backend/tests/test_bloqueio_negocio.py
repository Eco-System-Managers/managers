"""O bloqueio do negócio inteiro (Bloqueio sem colaborador): quem fecha, o que
sai da grade da esteira e da agenda, e o impedimento de fechar em cima de
cliente — inclusive o da esteira."""
from datetime import datetime, time, timedelta

import pytest
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APIClient

from apps_work.agenda.models import Agendamento, AgendamentoServico, Bloqueio
from apps_work.agenda.services import SlotsAgendaService
from apps_work.clientes.models import Cliente, Veiculo
from apps_work.empresa.models import HorarioFuncionamento
from apps_work.kanban.models import AtendimentoKanban
from apps_work.kanban.services import AtendimentoKanbanService, CapacidadeService, EtapaService
from apps_work.servicos.models import Servico
from apps_work.usuarios.models import Colaborador
from core.excecoes import ErroDeNegocio
from tenants.models import Membro

URL = '/api/v1/agenda/bloqueios/'
URL_SLOTS = '/api/v1/kanban/slots/'
URL_ATENDIMENTOS = '/api/v1/kanban/atendimentos/'

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
    """Todo dia das 9h às 14h, 1 por vez, sem máximo no dia."""
    for dia in range(7):
        HorarioFuncionamento.objects.update_or_create(
            dia=dia, defaults={'abertura': time(9, 0), 'fechamento': time(14, 0), 'ativo': True, 'vagas': 1},
        )


@pytest.fixture
def dono(patch_tenant_middleware, proprietario):
    return _client(proprietario)


@pytest.fixture
def leo(patch_tenant_middleware, tenant):
    return _membro(tenant, 'leo@x.com', 'parceiro')


@pytest.fixture
def joao(patch_tenant_middleware, tenant):
    return _membro(tenant, 'joao@x.com', 'colaborador')


@pytest.fixture
def etapas(patch_tenant_middleware):
    return EtapaService().criar_etapas_padrao()


@pytest.fixture
def lavagem(patch_tenant_middleware):
    return Servico.objects.create(nome='Lavagem', nicho='lava_rapido', duracao=40, preco='40.00')


@pytest.fixture
def corte(patch_tenant_middleware):
    return Servico.objects.create(nome='Corte', duracao=60, preco='50.00')


@pytest.fixture
def carro(patch_tenant_middleware):
    cliente = Cliente.objects.create(nome='Ana', telefone='11999990000')
    return Veiculo.objects.create(cliente=cliente, tipo='veiculo', placa='ABC1D23', marca='VW', modelo='Gol', porte='carro')


def _fechar(dia=DIA, data_fim=DIA, hora_inicio=time(12, 0), hora_fim=time(13, 0)) -> Bloqueio:
    """O negócio fechado: sem colaborador. Os padrões são o almoço de um dia."""
    return Bloqueio.objects.create(
        colaborador=None, data_inicio=dia, data_fim=data_fim, hora_inicio=hora_inicio, hora_fim=hora_fim,
    )


def _receber(etapas, carro, lavagem, hora=None, dia=DIA, **extra) -> AtendimentoKanban:
    return AtendimentoKanbanService().criar(
        etapa=etapas[0], objeto_id=carro.pk, servico_id=lavagem.pk, horario_entrada=hora, data=dia, **extra,
    )


def _agendar(colaborador, servico, dia, hora: time) -> Agendamento:
    cliente = Cliente.objects.create(nome='Bia', telefone='11999999999')
    ag = Agendamento.objects.create(
        cliente=cliente, colaborador=colaborador, data_hora=timezone.make_aware(datetime.combine(dia, hora)),
    )
    AgendamentoServico.objects.create(agendamento=ag, servico=servico, preco_cobrado='50.00')
    return ag


def _grade(api, lavagem, dia=DIA) -> list[str]:
    return [s['horario'] for s in api.get(URL_SLOTS, {'data': dia.isoformat(), 'servico': lavagem.pk}).data]


def _payload_negocio(**extra):
    return {'data_inicio': DIA.isoformat(), 'data_fim': DIA.isoformat(), 'hora_inicio': '12:00', 'hora_fim': '13:00', **extra}


@pytest.mark.django_db
class TestQuemFechaONegocio:
    def test_dono_fecha_sem_colaborador(self, dono):
        response = dono.post(URL, _payload_negocio(motivo='Almoço'), format='json')

        assert response.status_code == 201
        assert response.json()['colaborador'] is None
        assert response.json()['colaborador_nome'] is None
        assert Bloqueio.objects.get().colaborador_id is None

    def test_colaborador_nulo_explicito_tambem_e_o_negocio(self, dono):
        response = dono.post(URL, _payload_negocio(colaborador=None), format='json')

        assert response.status_code == 201
        assert response.json()['colaborador'] is None

    def test_parceiro_nao_fecha_o_negocio(self, leo):
        response = _client(leo.user).post(URL, _payload_negocio(), format='json')

        assert response.status_code == 403
        assert response.json()['code'] == 'sem_permissao'
        assert not Bloqueio.objects.exists()

    def test_colaborador_comum_nao_fecha_o_negocio(self, joao):
        response = _client(joao.user).post(URL, _payload_negocio(), format='json')

        assert response.status_code == 403
        assert response.json()['code'] == 'sem_permissao'

    def test_parceiro_continua_bloqueando_a_propria_agenda(self, leo):
        response = _client(leo.user).post(URL, _payload_negocio(colaborador=leo.pk), format='json')

        assert response.status_code == 201
        assert response.json()['colaborador_nome'] == 'leo@x.com'

    def test_so_o_dono_exclui_o_do_negocio(self, dono, leo):
        bloqueio = _fechar()

        assert _client(leo.user).delete(f'{URL}{bloqueio.pk}/').status_code == 403
        assert _client(leo.user).delete(f'{URL}{bloqueio.pk}/').json()['code'] == 'sem_permissao'
        assert dono.delete(f'{URL}{bloqueio.pk}/').status_code == 204
        assert not Bloqueio.objects.exists()

    def test_listar_por_dia_traz_o_do_negocio_e_por_colaborador_tambem(self, dono, leo, joao):
        _fechar()
        Bloqueio.objects.create(colaborador=leo, data_inicio=DIA, data_fim=DIA, hora_inicio=time(9, 0), hora_fim=time(10, 0))
        Bloqueio.objects.create(colaborador=joao, data_inicio=DIA, data_fim=DIA, hora_inicio=time(9, 0), hora_fim=time(10, 0))

        do_dia = dono.get(URL, {'data': DIA.isoformat()}).json()
        de_leo = dono.get(URL, {'data': DIA.isoformat(), 'colaborador': leo.pk}).json()

        assert do_dia['count'] == 3
        # a agenda do Léo tem o bloqueio dele e o fechamento do negócio; o do João fica de fora
        assert de_leo['count'] == 2
        assert sorted((b['colaborador'] for b in de_leo['results']), key=lambda c: (c is not None, c or 0)) == [None, leo.pk]


@pytest.mark.django_db
class TestEsteiraRespeitaOFechamento:
    def test_a_grade_some_no_almoco_e_volta_no_fim_dele(self, dono, expediente, lavagem):
        _fechar()

        grade = _grade(dono, lavagem)

        assert '11:15' in grade  # 11:15 + 40 = 11:55, encosta no almoço
        assert '11:30' not in grade
        assert '12:00' not in grade
        assert '12:45' not in grade
        assert '13:00' in grade  # o fim do bloqueio é oferecido

    def test_com_duas_vagas_o_fechamento_ocupa_as_duas(self, dono, expediente, lavagem):
        CapacidadeService().ajustar(DIA, capacidade=None, vagas=2)
        _fechar()

        assert '12:00' not in _grade(dono, lavagem)
        assert '13:00' in _grade(dono, lavagem)

    def test_dia_inteiro_zera_a_grade(self, dono, expediente, lavagem):
        _fechar(hora_inicio=None, hora_fim=None)

        assert _grade(dono, lavagem) == []
        assert '12:00' in _grade(dono, lavagem, DIA + timedelta(days=1))

    def test_fixo_vale_nos_dias_seguintes(self, dono, expediente, lavagem):
        _fechar(data_fim=None)

        assert '12:00' not in _grade(dono, lavagem, DIA + timedelta(days=20))

    def test_conferir_recusa_hora_dentro_do_bloqueio(self, expediente, lavagem):
        _fechar()

        with pytest.raises(ErroDeNegocio) as erro:
            CapacidadeService().conferir(DIA, 40, time(12, 15))
        assert erro.value.code == 'horario_bloqueado'

        # a que termina dentro do bloqueio também
        with pytest.raises(ErroDeNegocio) as erro:
            CapacidadeService().conferir(DIA, 40, time(11, 30))
        assert erro.value.code == 'horario_bloqueado'

        # a mesma regra sem conferir o máximo do dia (remarcação no mesmo dia)
        with pytest.raises(ErroDeNegocio) as erro:
            CapacidadeService().conferir(DIA, 40, time(12, 15), conferir_dia=False)
        assert erro.value.code == 'horario_bloqueado'

        CapacidadeService().conferir(DIA, 40, time(13, 0))

    def test_receber_na_hora_fechada_e_recusado_mesmo_ignorando_o_limite(self, dono, expediente, etapas, carro, lavagem):
        _fechar()
        payload = {
            'etapa': etapas[0].pk, 'objeto': carro.pk, 'servico': lavagem.pk,
            'data': DIA.isoformat(), 'horario_entrada': '12:15',
        }

        response = dono.post(URL_ATENDIMENTOS, payload, format='json')
        assert response.status_code == 400
        assert response.data['code'] == 'horario_bloqueado'

        response = dono.post(URL_ATENDIMENTOS, {**payload, 'ignorar_limite': True}, format='json')
        assert response.status_code == 400
        assert response.data['code'] == 'horario_bloqueado'
        assert not AtendimentoKanban.objects.exists()

    def test_o_bloqueio_vem_antes_do_horario_ocupado(self, dono, expediente, etapas, carro, lavagem):
        """Com a hora cheia e fechada, o dono ouve o que não tem ignorar."""
        _receber(etapas, carro, lavagem, time(12, 0), ignorar_limite=True)
        _fechar()

        response = dono.post(URL_ATENDIMENTOS, {
            'etapa': etapas[0].pk, 'objeto': carro.pk, 'servico': lavagem.pk,
            'data': DIA.isoformat(), 'horario_entrada': '12:00',
        }, format='json')

        assert response.data['code'] == 'horario_bloqueado'

    def test_sem_hora_continua_entrando_no_dia_fechado(self, dono, expediente, etapas, carro, lavagem):
        """O dia inteiro fechado tira a grade, mas o card sem hora (quem
        chegou) ainda é lançado: o bloqueio fecha a marcação, não o pátio."""
        _fechar(hora_inicio=None, hora_fim=None)

        response = dono.post(URL_ATENDIMENTOS, {
            'etapa': etapas[0].pk, 'objeto': carro.pk, 'servico': lavagem.pk, 'data': DIA.isoformat(),
        }, format='json')

        assert response.status_code == 201

    def test_remarcar_para_dentro_do_bloqueio_e_recusado_mesmo_ignorando_o_limite(self, dono, expediente, etapas, carro, lavagem):
        atendimento = _receber(etapas, carro, lavagem, time(9, 0))
        _fechar()
        url = f'{URL_ATENDIMENTOS}{atendimento.pk}/'

        response = dono.patch(url, {'horario_entrada': '12:30'}, format='json')
        assert response.status_code == 400
        assert response.data['code'] == 'horario_bloqueado'

        response = dono.patch(url, {'horario_entrada': '12:30', 'ignorar_limite': True}, format='json')
        assert response.status_code == 400
        assert response.data['code'] == 'horario_bloqueado'

        # para outro dia, em que não há bloqueio, passa
        amanha = DIA + timedelta(days=1)
        response = dono.patch(url, {'data': amanha.isoformat(), 'horario_entrada': '12:30'}, format='json')
        assert response.status_code == 200

    def test_trocar_para_um_servico_que_invade_o_bloqueio_e_recusado(self, dono, expediente, etapas, carro, lavagem):
        polimento = Servico.objects.create(nome='Polimento', nicho='lava_rapido', duracao=90, preco='150.00')
        atendimento = _receber(etapas, carro, lavagem, time(11, 0))  # até 11:40
        _fechar()

        response = dono.patch(
            f'{URL_ATENDIMENTOS}{atendimento.pk}/', {'servico': polimento.pk, 'ignorar_limite': True}, format='json',
        )

        assert response.status_code == 400
        assert response.data['code'] == 'horario_bloqueado'

    def test_o_bloqueio_de_um_profissional_nao_fecha_a_esteira(self, dono, expediente, leo, lavagem):
        Bloqueio.objects.create(colaborador=leo, data_inicio=DIA, data_fim=DIA, hora_inicio=time(12, 0), hora_fim=time(13, 0))

        assert '12:00' in _grade(dono, lavagem)


@pytest.mark.django_db
class TestAgendaRespeitaOFechamento:
    def test_a_grade_de_todo_profissional_perde_o_trecho(self, expediente, leo, joao):
        _fechar()

        for colaborador in (leo, joao):
            horarios = [i.strftime('%H:%M') for i in SlotsAgendaService().livres(DIA, colaborador.pk, 60)]
            assert '11:00' in horarios
            assert '11:15' not in horarios
            assert '12:00' not in horarios
            assert '13:00' in horarios

    def test_marcar_em_cima_do_fechamento_e_recusado(self, dono, expediente, leo, corte):
        _fechar()
        cliente = Cliente.objects.create(nome='Ana', telefone='11999999999')
        quando = timezone.make_aware(datetime.combine(DIA, time(12, 0)))

        response = dono.post('/api/v1/agendamentos/', {
            'cliente': cliente.pk, 'colaborador': leo.pk, 'servico_id': corte.pk, 'data_hora': quando.isoformat(),
        }, format='json')

        assert response.status_code == 400
        assert response.json()['code'] == 'horario_bloqueado'


@pytest.mark.django_db
class TestFecharEmCimaDeCliente:
    def test_atendimento_da_esteira_com_hora_impede(self, dono, expediente, etapas, carro, lavagem):
        _receber(etapas, carro, lavagem, time(12, 30))

        response = dono.post(URL, _payload_negocio(), format='json')

        assert response.status_code == 400
        assert response.json()['code'] == 'bloqueio_com_cliente'
        assert not Bloqueio.objects.exists()

    def test_o_tempo_a_mais_previsto_conta(self, dono, expediente, etapas, carro, lavagem):
        _receber(etapas, carro, lavagem, time(11, 0), minutos_extras=90)  # até 13:10

        response = dono.post(URL, _payload_negocio(), format='json')

        assert response.json()['code'] == 'bloqueio_com_cliente'

    def test_atendimento_que_encosta_nao_impede(self, dono, expediente, etapas, carro, lavagem):
        _receber(etapas, carro, lavagem, time(11, 20))  # termina às 12:00

        assert dono.post(URL, _payload_negocio(), format='json').status_code == 201

    def test_quem_faltou_nao_impede(self, dono, expediente, etapas, carro, lavagem):
        faltou = _receber(etapas, carro, lavagem, time(12, 30))
        AtendimentoKanbanService().marcar_falta(faltou)

        assert dono.post(URL, _payload_negocio(), format='json').status_code == 201

    def test_sem_hora_nao_impede(self, dono, expediente, etapas, carro, lavagem):
        _receber(etapas, carro, lavagem)

        assert dono.post(URL, _payload_negocio(), format='json').status_code == 201
        # nem o dia inteiro: o card fica marcado, só não entra mais ninguém
        assert dono.post(URL, {'data_inicio': DIA.isoformat(), 'data_fim': DIA.isoformat()}, format='json').status_code == 201

    def test_fixo_olha_as_semanas_seguintes_na_esteira(self, dono, expediente, etapas, carro, lavagem):
        _receber(etapas, carro, lavagem, time(12, 0), dia=DIA + timedelta(days=14))

        response = dono.post(URL, {'data_inicio': DIA.isoformat(), 'hora_inicio': '12:00', 'hora_fim': '13:00'}, format='json')

        assert response.json()['code'] == 'bloqueio_com_cliente'

    def test_agendamento_de_qualquer_profissional_impede(self, dono, expediente, leo, joao, corte):
        _agendar(joao, corte, DIA, time(12, 30))

        response = dono.post(URL, _payload_negocio(), format='json')

        assert response.json()['code'] == 'bloqueio_com_cliente'

    def test_o_bloqueio_de_um_profissional_nao_olha_a_esteira(self, dono, expediente, leo, etapas, carro, lavagem):
        _receber(etapas, carro, lavagem, time(12, 30))

        assert dono.post(URL, _payload_negocio(colaborador=leo.pk), format='json').status_code == 201
