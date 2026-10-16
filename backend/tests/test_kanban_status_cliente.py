import pytest
from unittest.mock import patch

from django.db import connection
from django.test import override_settings
from django_tenants.middleware.main import TenantMainMiddleware
from rest_framework.test import APIClient

from apps_serv.autenticacao.authentication import gerar_tokens
from apps_serv.consumidores.models import AgendamentoConsumidor
from apps_serv.consumidores.services import RegistroConsumidorService
from apps_serv.vitrine.services import StatusKanbanAgendamentosService
from apps_work.kanban.models import EtapaKanban
from apps_work.kanban.services import EtapaService, StatusClienteService


@pytest.fixture
def patch_public_middleware():
    def _process_request(_self, request):
        connection.set_schema_to_public()

    with override_settings(ALLOWED_HOSTS=['*']):
        with patch.object(TenantMainMiddleware, 'process_request', _process_request):
            yield


@pytest.fixture
def consumidor(db):
    return RegistroConsumidorService().registrar(
        nome='Carlos Cliente',
        email='carlos@sm.com',
        senha='SenhaForte123!',
    )


@pytest.fixture
def api_autenticado(patch_public_middleware, consumidor):
    access, _ = gerar_tokens(consumidor)
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {access}')
    return client, consumidor


def _criar_etapas(nomes: list[str]) -> list[EtapaKanban]:
    return [
        EtapaKanban.objects.create(nome=nome, ordem=i)
        for i, nome in enumerate(nomes)
    ]


# ---------------------------------------------------------------------------
# Tradução posicional coluna -> status do cliente
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestStatusClienteService:
    def test_quadro_padrao_primeira_coluna_e_aguardando(self, patch_tenant_middleware):
        etapas = EtapaService().criar_etapas_padrao()
        mapa = StatusClienteService().mapa_por_etapa()
        assert mapa[etapas[0].id] == 'aguardando'

    def test_quadro_padrao_coluna_do_meio_e_em_atendimento(self, patch_tenant_middleware):
        etapas = EtapaService().criar_etapas_padrao()
        mapa = StatusClienteService().mapa_por_etapa()
        assert mapa[etapas[1].id] == 'em_atendimento'

    def test_quadro_padrao_ultima_coluna_e_concluido(self, patch_tenant_middleware):
        etapas = EtapaService().criar_etapas_padrao()
        mapa = StatusClienteService().mapa_por_etapa()
        assert mapa[etapas[2].id] == 'concluido'

    def test_quadro_com_cinco_colunas_agrupa_o_miolo_em_atendimento(self, patch_tenant_middleware):
        etapas = _criar_etapas(['Recebido', 'Lavando', 'Secando', 'Polindo', 'Pronto'])
        mapa = StatusClienteService().mapa_por_etapa()
        assert [mapa[e.id] for e in etapas] == [
            'aguardando', 'em_atendimento', 'em_atendimento', 'em_atendimento', 'concluido',
        ]

    def test_quadro_com_duas_colunas_nao_tem_em_atendimento(self, patch_tenant_middleware):
        etapas = _criar_etapas(['Fila', 'Pronto'])
        mapa = StatusClienteService().mapa_por_etapa()
        assert [mapa[e.id] for e in etapas] == ['aguardando', 'concluido']

    def test_quadro_com_uma_coluna_e_sempre_aguardando(self, patch_tenant_middleware):
        """Sem coluna seguinte não há como concluir — o card fica em espera."""
        etapas = _criar_etapas(['Unica'])
        mapa = StatusClienteService().mapa_por_etapa()
        assert mapa[etapas[0].id] == 'aguardando'

    def test_quadro_sem_colunas_retorna_mapa_vazio(self, patch_tenant_middleware):
        assert StatusClienteService().mapa_por_etapa() == {}

    def test_reordenar_colunas_muda_o_status(self, patch_tenant_middleware):
        """O status segue a ordem visual do quadro, não o nome nem o id."""
        etapas = _criar_etapas(['Fila', 'Lavando', 'Pronto'])
        EtapaService().reordenar([
            {'id': etapas[2].id, 'ordem': 0},
            {'id': etapas[1].id, 'ordem': 1},
            {'id': etapas[0].id, 'ordem': 2},
        ])
        mapa = StatusClienteService().mapa_por_etapa()
        assert mapa[etapas[2].id] == 'aguardando'


# ---------------------------------------------------------------------------
# Agrupamento por negócio
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestStatusKanbanAgendamentosService:
    def _agendamento(self, consumidor, schema_name, agendamento_id, origem='kanban', status='agendado'):
        from django.utils import timezone
        return AgendamentoConsumidor.objects.create(
            consumidor=consumidor,
            schema_name=schema_name,
            agendamento_id=agendamento_id,
            origem=origem,
            negocio_nome='Negocio',
            data_hora=timezone.now(),
            duracao_total=30,
            valor_total='50.00',
            status=status,
        )

    def test_agendamento_de_agenda_e_ignorado(self, consumidor):
        ag = self._agendamento(consumidor, 'barbearia_x', 1, origem='agenda')
        with patch('apps_serv.vitrine.services.CrossTenantQueryService') as MockSvc:
            resultado = StatusKanbanAgendamentosService().por_agendamento([ag])
        assert resultado == {}
        MockSvc.return_value.status_kanban.assert_not_called()

    def test_agendamento_cancelado_e_ignorado(self, consumidor):
        ag = self._agendamento(consumidor, 'lava_x', 1, status='cancelado')
        with patch('apps_serv.vitrine.services.CrossTenantQueryService') as MockSvc:
            resultado = StatusKanbanAgendamentosService().por_agendamento([ag])
        assert resultado == {}
        MockSvc.return_value.status_kanban.assert_not_called()

    def test_troca_de_schema_uma_vez_por_negocio(self, consumidor):
        """Dois atendimentos no mesmo negócio = uma única consulta."""
        ag1 = self._agendamento(consumidor, 'lava_x', 1)
        ag2 = self._agendamento(consumidor, 'lava_x', 2)
        with patch('apps_serv.vitrine.services.CrossTenantQueryService') as MockSvc:
            MockSvc.return_value.status_kanban.return_value = {}
            StatusKanbanAgendamentosService().por_agendamento([ag1, ag2])
        assert MockSvc.return_value.status_kanban.call_count == 1

    def test_mapeia_status_por_id_do_agendamento(self, consumidor):
        ag = self._agendamento(consumidor, 'lava_x', 7)
        with patch('apps_serv.vitrine.services.CrossTenantQueryService') as MockSvc:
            MockSvc.return_value.status_kanban.return_value = {
                7: {'status_kanban': 'em_atendimento', 'etapa_nome': 'Lavando'},
            }
            resultado = StatusKanbanAgendamentosService().por_agendamento([ag])
        assert resultado[ag.id]['status_kanban'] == 'em_atendimento'

    def test_negocio_indisponivel_nao_derruba_os_demais(self, consumidor):
        """Schema removido em um negócio não pode quebrar a agenda inteira."""
        quebrado = self._agendamento(consumidor, 'schema_morto', 1)
        ok = self._agendamento(consumidor, 'lava_x', 2)

        def _status(schema_name, ids):
            if schema_name == 'schema_morto':
                raise RuntimeError('schema não existe')
            return {2: {'status_kanban': 'concluido', 'etapa_nome': 'Pronto'}}

        with patch('apps_serv.vitrine.services.CrossTenantQueryService') as MockSvc:
            MockSvc.return_value.status_kanban.side_effect = _status
            resultado = StatusKanbanAgendamentosService().por_agendamento([quebrado, ok])

        assert resultado[ok.id]['status_kanban'] == 'concluido'

    def test_negocio_indisponivel_fica_sem_status(self, consumidor):
        quebrado = self._agendamento(consumidor, 'schema_morto', 1)
        with patch('apps_serv.vitrine.services.CrossTenantQueryService') as MockSvc:
            MockSvc.return_value.status_kanban.side_effect = RuntimeError('boom')
            resultado = StatusKanbanAgendamentosService().por_agendamento([quebrado])
        assert quebrado.id not in resultado


# ---------------------------------------------------------------------------
# GET /api/sm/agendamentos/
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestStatusKanbanNaAgendaAPI:
    def _agendamento_kanban(self, consumidor):
        from django.utils import timezone
        return AgendamentoConsumidor.objects.create(
            consumidor=consumidor,
            schema_name='lava_x',
            agendamento_id=5,
            origem='kanban',
            negocio_nome='Lava Rapido X',
            data_hora=timezone.now(),
            duracao_total=60,
            valor_total='80.00',
            status='agendado',
        )

    def test_resposta_traz_status_kanban(self, api_autenticado):
        client, consumidor = api_autenticado
        self._agendamento_kanban(consumidor)
        with patch('apps_serv.vitrine.services.CrossTenantQueryService') as MockSvc:
            MockSvc.return_value.status_kanban.return_value = {
                5: {'status_kanban': 'em_atendimento', 'etapa_nome': 'Lavando'},
            }
            response = client.get('/api/sm/agendamentos/')
        assert response.data['results'][0]['status_kanban'] == 'em_atendimento'

    def test_resposta_traz_nome_real_da_coluna(self, api_autenticado):
        client, consumidor = api_autenticado
        self._agendamento_kanban(consumidor)
        with patch('apps_serv.vitrine.services.CrossTenantQueryService') as MockSvc:
            MockSvc.return_value.status_kanban.return_value = {
                5: {'status_kanban': 'em_atendimento', 'etapa_nome': 'Lavando'},
            }
            response = client.get('/api/sm/agendamentos/')
        assert response.data['results'][0]['etapa_nome'] == 'Lavando'

    def test_resposta_traz_origem(self, api_autenticado):
        client, consumidor = api_autenticado
        self._agendamento_kanban(consumidor)
        with patch('apps_serv.vitrine.services.CrossTenantQueryService') as MockSvc:
            MockSvc.return_value.status_kanban.return_value = {}
            response = client.get('/api/sm/agendamentos/')
        assert response.data['results'][0]['origem'] == 'kanban'

    def test_agendamento_de_agenda_tem_status_kanban_nulo(self, api_autenticado):
        from django.utils import timezone
        client, consumidor = api_autenticado
        AgendamentoConsumidor.objects.create(
            consumidor=consumidor, schema_name='barbearia_x', agendamento_id=1,
            origem='agenda', negocio_nome='Barbearia X', data_hora=timezone.now(),
            duracao_total=30, valor_total='50.00', status='agendado',
        )
        response = client.get('/api/sm/agendamentos/')
        assert response.data['results'][0]['status_kanban'] is None

    def test_sem_auth_retorna_401(self, patch_public_middleware):
        client = APIClient()
        response = client.get('/api/sm/agendamentos/')
        assert response.status_code == 401
