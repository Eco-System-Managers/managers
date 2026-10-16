import pytest
from datetime import date, datetime, timedelta

from django.utils import timezone
from rest_framework.test import APIClient

from apps_work.agenda.models import Agendamento, AgendamentoServico
from apps_work.agenda.services import PendenciasCobrancaService
from apps_work.clientes.models import Cliente, ObjetoCliente, Veiculo
from apps_work.kanban.models import AtendimentoKanban, EtapaKanban
from apps_work.servicos.models import Servico

HOJE = date(2026, 6, 15)


@pytest.fixture
def client_autenticado(patch_tenant_middleware, usuario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=usuario)
    return client


@pytest.fixture
def servico(patch_tenant_middleware):
    return Servico.objects.create(nome='Corte', duracao=30, preco='50.00')


def _agendamento(dia: int, status: str = 'agendado', servico=None, preco='50.00') -> Agendamento:
    cliente = Cliente.objects.create(nome=f'Cliente {dia}', telefone='11999999999')
    ag = Agendamento.objects.create(
        cliente=cliente,
        data_hora=timezone.make_aware(datetime(2026, 6, dia, 10, 0)),
        status=status,
    )
    if servico:
        AgendamentoServico.objects.create(agendamento=ag, servico=servico, preco_cobrado=preco)
    return ag


def _atendimento(dia: int | None, pago: bool = False, servico=None) -> AtendimentoKanban:
    cliente = Cliente.objects.create(nome=f'Dono {dia}', telefone='11988887777')
    veiculo = Veiculo.objects.create(cliente=cliente, tipo='veiculo', placa=f'XYZ{dia or 0:04d}')
    etapa = EtapaKanban.objects.create(nome=f'Etapa {dia}', ordem=dia or 0)
    return AtendimentoKanban.objects.create(
        etapa=etapa,
        objeto=ObjetoCliente.objects.get(pk=veiculo.pk),
        servico=servico,
        data=date(2026, 6, dia) if dia else None,
        pago=pago,
    )


@pytest.mark.django_db
class TestPendenciasDaAgenda:
    def test_agendamento_passado_sem_cobranca_aparece(self, patch_tenant_middleware, servico):
        _agendamento(10, servico=servico)
        assert len(PendenciasCobrancaService().listar(HOJE)) == 1

    def test_agendamento_de_hoje_nao_aparece(self, patch_tenant_middleware, servico):
        """Ainda dá tempo de cobrar — pendência é só o que já passou."""
        _agendamento(15, servico=servico)
        assert PendenciasCobrancaService().listar(HOJE) == []

    def test_agendamento_futuro_nao_aparece(self, patch_tenant_middleware, servico):
        _agendamento(20, servico=servico)
        assert PendenciasCobrancaService().listar(HOJE) == []

    def test_agendamento_concluido_nao_aparece(self, patch_tenant_middleware, servico):
        _agendamento(10, status='concluido', servico=servico)
        assert PendenciasCobrancaService().listar(HOJE) == []

    def test_agendamento_cancelado_nao_aparece(self, patch_tenant_middleware, servico):
        _agendamento(10, status='cancelado', servico=servico)
        assert PendenciasCobrancaService().listar(HOJE) == []

    def test_agendamento_faltou_nao_aparece(self, patch_tenant_middleware, servico):
        """Já foi resolvido pelo dono: não gera cobrança e sai da lista."""
        _agendamento(10, status='faltou', servico=servico)
        assert PendenciasCobrancaService().listar(HOJE) == []

    def test_confirmado_tambem_conta(self, patch_tenant_middleware, servico):
        _agendamento(10, status='confirmado', servico=servico)
        assert len(PendenciasCobrancaService().listar(HOJE)) == 1

    def test_valor_desconta_o_desconto(self, patch_tenant_middleware, servico):
        ag = _agendamento(10, servico=servico, preco='50.00')
        ag.desconto = '10.00'
        ag.save(update_fields=['desconto'])
        assert PendenciasCobrancaService().listar(HOJE)[0]['valor'] == '40.00'

    def test_traz_nome_do_cliente_e_do_servico(self, patch_tenant_middleware, servico):
        _agendamento(10, servico=servico)
        item = PendenciasCobrancaService().listar(HOJE)[0]
        assert item['servico_nome'] == 'Corte'


@pytest.mark.django_db
class TestPendenciasDaEsteira:
    def test_atendimento_passado_nao_pago_aparece(self, patch_tenant_middleware, servico):
        _atendimento(10, servico=servico)
        assert len(PendenciasCobrancaService().listar(HOJE)) == 1

    def test_atendimento_pago_nao_aparece(self, patch_tenant_middleware, servico):
        _atendimento(10, pago=True, servico=servico)
        assert PendenciasCobrancaService().listar(HOJE) == []

    def test_atendimento_sem_data_nao_aparece(self, patch_tenant_middleware, servico):
        """Sem data não dá pra dizer que atrasou."""
        _atendimento(None, servico=servico)
        assert PendenciasCobrancaService().listar(HOJE) == []

    def test_atendimento_de_hoje_nao_aparece(self, patch_tenant_middleware, servico):
        _atendimento(15, servico=servico)
        assert PendenciasCobrancaService().listar(HOJE) == []

    def test_identifica_a_origem(self, patch_tenant_middleware, servico):
        _atendimento(10, servico=servico)
        assert PendenciasCobrancaService().listar(HOJE)[0]['origem'] == 'kanban'


@pytest.mark.django_db
class TestPendenciasCombinadas:
    def test_junta_as_duas_origens(self, patch_tenant_middleware, servico):
        _agendamento(10, servico=servico)
        _atendimento(11, servico=servico)
        assert len(PendenciasCobrancaService().listar(HOJE)) == 2

    def test_mais_antigo_vem_primeiro(self, patch_tenant_middleware, servico):
        _agendamento(12, servico=servico)
        _atendimento(5, servico=servico)
        pendencias = PendenciasCobrancaService().listar(HOJE)
        assert pendencias[0]['data'] == '2026-06-05'


@pytest.mark.django_db
class TestPendenciasAPI:
    def test_retorna_200(self, client_autenticado):
        response = client_autenticado.get('/api/agenda/pendencias/')
        assert response.status_code == 200

    def test_lista_pendencia_criada(self, client_autenticado, servico):
        cliente = Cliente.objects.create(nome='Atrasado', telefone='11999999999')
        ontem = timezone.now() - timedelta(days=1)
        ag = Agendamento.objects.create(cliente=cliente, data_hora=ontem, status='agendado')
        AgendamentoServico.objects.create(agendamento=ag, servico=servico, preco_cobrado='50.00')

        response = client_autenticado.get('/api/agenda/pendencias/')

        assert [p['id'] for p in response.data] == [ag.pk]

    def test_agendamento_de_hoje_fica_fora_da_api(self, client_autenticado, servico):
        cliente = Cliente.objects.create(nome='De hoje', telefone='11999999999')
        ag = Agendamento.objects.create(cliente=cliente, data_hora=timezone.now(), status='agendado')
        AgendamentoServico.objects.create(agendamento=ag, servico=servico, preco_cobrado='50.00')

        response = client_autenticado.get('/api/agenda/pendencias/')

        assert response.data == []

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/agenda/pendencias/')
        assert response.status_code == 401


@pytest.mark.django_db
class TestDescartePendenciaComConflito:
    """O botão "Faltou" da lista de pendências é um PATCH de status puro.

    Pendência é, por definição, agendamento velho e acumulado — dois no mesmo
    horário do mesmo colaborador é o caso comum. Revalidar o horário nessa
    edição travava justamente os registros que a lista existe pra resolver.
    """

    @pytest.fixture
    def colaborador(self, patch_tenant_middleware, usuario):
        from apps_work.usuarios.models import Colaborador
        return Colaborador.objects.create(user=usuario)

    def _com_colaborador(self, colaborador, servico, nome: str, quando) -> Agendamento:
        cliente = Cliente.objects.create(nome=nome, telefone='11999999999')
        ag = Agendamento.objects.create(
            cliente=cliente, colaborador=colaborador, data_hora=quando, status='agendado',
        )
        AgendamentoServico.objects.create(agendamento=ag, servico=servico, preco_cobrado='50.00')
        return ag

    def test_marcar_faltou_passa_apesar_de_conflito_preexistente(
        self, client_autenticado, colaborador, servico,
    ):
        quando = timezone.make_aware(datetime(2026, 6, 10, 10, 0))
        alvo = self._com_colaborador(colaborador, servico, 'Alvo', quando)
        self._com_colaborador(colaborador, servico, 'Choque', quando)

        response = client_autenticado.patch(
            f'/api/agendamentos/{alvo.pk}/', {'status': 'faltou'}, format='json',
        )

        assert response.status_code == 200

    def test_reagendar_para_horario_ocupado_continua_barrado(
        self, client_autenticado, colaborador, servico,
    ):
        alvo = self._com_colaborador(
            colaborador, servico, 'Alvo', timezone.make_aware(datetime(2026, 6, 10, 9, 0)),
        )
        ocupado = timezone.make_aware(datetime(2026, 6, 10, 14, 0))
        self._com_colaborador(colaborador, servico, 'Ocupa', ocupado)

        response = client_autenticado.patch(
            f'/api/agendamentos/{alvo.pk}/',
            {'data_hora': ocupado.isoformat()},
            format='json',
        )

        assert response.status_code == 400
