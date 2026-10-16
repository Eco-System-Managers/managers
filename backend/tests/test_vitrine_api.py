import pytest
from decimal import Decimal
from datetime import timedelta
from unittest.mock import MagicMock, patch

from django.db import connection
from django.utils import timezone
from django_tenants.middleware.main import TenantMainMiddleware
from django.test import override_settings
from rest_framework.test import APIClient

from apps_serv.autenticacao.authentication import gerar_tokens
from apps_serv.consumidores.services import RegistroConsumidorService
from apps_serv.vitrine.models import NegocioPublico


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def patch_public_middleware():
    def _process_request(_self, request):
        connection.set_schema_to_public()

    with override_settings(ALLOWED_HOSTS=['*']):
        with patch.object(TenantMainMiddleware, 'process_request', _process_request):
            yield


@pytest.fixture
def negocio(db):
    return NegocioPublico.objects.create(
        schema_name='barbearia_x',
        nome='Barbearia X',
        nicho='Barbearia',
        latitude='-23.550000',
        longitude='-46.633000',
        ativo=True,
    )


@pytest.fixture
def negocio_inativo(db):
    return NegocioPublico.objects.create(
        schema_name='barbearia_fechada',
        nome='Fechada',
        nicho='Barbearia',
        latitude='-23.550000',
        longitude='-46.633000',
        ativo=False,
    )


@pytest.fixture
def consumidor(db):
    return RegistroConsumidorService().registrar(
        nome='Carlos Cliente',
        email='carlos@sm.com',
        senha='SenhaForte123!',
    )


@pytest.fixture
def api(patch_public_middleware):
    return APIClient()


@pytest.fixture
def api_autenticado(patch_public_middleware, consumidor):
    access, _ = gerar_tokens(consumidor)
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {access}')
    return client, consumidor


# ---------------------------------------------------------------------------
# GET /api/sm/negocios/
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestNegociosPublicos:
    def test_lista_somente_negocios_ativos(self, api, negocio, negocio_inativo):
        response = api.get('/api/sm/negocios/')
        assert response.status_code == 200
        nomes = [n['nome'] for n in response.data]
        assert 'Barbearia X' in nomes
        assert 'Fechada' not in nomes

    def test_filtra_por_nicho(self, api, db):
        NegocioPublico.objects.create(
            schema_name='lavacao_y', nome='Lava-Rápido Y', nicho='Lava-Rápido',
            latitude='-23.5', longitude='-46.6', ativo=True,
        )
        NegocioPublico.objects.create(
            schema_name='barbearia_z', nome='Barbearia Z', nicho='Barbearia',
            latitude='-23.5', longitude='-46.6', ativo=True,
        )
        response = api.get('/api/sm/negocios/?nicho=Barbearia')
        assert response.status_code == 200
        schemas = [n['schema_name'] for n in response.data]
        assert 'barbearia_z' in schemas
        assert 'lavacao_y' not in schemas

    def test_lista_vazia_sem_negocios_ativos(self, api, negocio_inativo):
        response = api.get('/api/sm/negocios/')
        assert response.status_code == 200
        schemas = [n['schema_name'] for n in response.data]
        assert negocio_inativo.schema_name not in schemas

    def test_endpoint_publico_sem_auth(self, api, negocio):
        response = api.get('/api/sm/negocios/')
        assert response.status_code == 200


# ---------------------------------------------------------------------------
# GET /api/sm/negocios/?search=  e  GET /api/sm/negocios/nichos/
# ---------------------------------------------------------------------------

@pytest.fixture
def vitrine_variada(db):
    NegocioPublico.objects.create(
        schema_name='barbearia_do_ze', nome='Barbearia do Zé', nicho='barbearia',
        cidade='Campinas', latitude='-23.5', longitude='-46.6', ativo=True,
    )
    NegocioPublico.objects.create(
        schema_name='banho_feliz', nome='Pet Feliz', nicho='banho_tosa',
        cidade='Santos', latitude='-23.5', longitude='-46.6', ativo=True,
    )
    NegocioPublico.objects.create(
        schema_name='lava_jato_sp', nome='Lava Jato SP', nicho='lava_rapido',
        cidade='Campinas', latitude='-23.5', longitude='-46.6', ativo=True,
    )


@pytest.mark.django_db
class TestBuscaDeNegocios:
    def _schemas(self, response):
        return {n['schema_name'] for n in response.data}

    def test_busca_por_nome(self, api, vitrine_variada):
        response = api.get('/api/sm/negocios/?search=barbearia do')
        assert self._schemas(response) == {'barbearia_do_ze'}

    def test_busca_por_cidade(self, api, vitrine_variada):
        response = api.get('/api/sm/negocios/?search=santos')
        assert self._schemas(response) == {'banho_feliz'}

    def test_busca_por_nicho(self, api, vitrine_variada):
        response = api.get('/api/sm/negocios/?search=banho')
        assert self._schemas(response) == {'banho_feliz'}

    def test_busca_ignora_maiusculas(self, api, vitrine_variada):
        response = api.get('/api/sm/negocios/?search=LAVA')
        assert self._schemas(response) == {'lava_jato_sp'}

    def test_busca_vazia_retorna_todos(self, api, vitrine_variada):
        response = api.get('/api/sm/negocios/?search=')
        assert len(response.data) == 3

    def test_busca_sem_resultado_retorna_lista_vazia(self, api, vitrine_variada):
        response = api.get('/api/sm/negocios/?search=inexistente')
        assert response.data == []

    def test_busca_combina_com_filtro_de_nicho(self, api, vitrine_variada):
        """Chip de nicho e caixa de busca sao filtros independentes e somam."""
        response = api.get('/api/sm/negocios/?search=campinas&nicho=lava_rapido')
        assert self._schemas(response) == {'lava_jato_sp'}

    def test_nao_retorna_negocio_inativo(self, api, vitrine_variada, negocio_inativo):
        response = api.get('/api/sm/negocios/?search=fechada')
        assert response.data == []


@pytest.mark.django_db
class TestFiltroPorArea:
    """Sao Paulo e o ponto de referencia; Campinas fica a ~90km, Recife a ~2600km."""

    @pytest.fixture(autouse=True)
    def _vitrine_geografica(self, db):
        NegocioPublico.objects.create(
            schema_name='sp_centro', nome='SP Centro', nicho='barbearia',
            cidade='São Paulo', latitude='-23.550000', longitude='-46.633000', ativo=True,
        )
        NegocioPublico.objects.create(
            schema_name='campinas', nome='Campinas', nicho='barbearia',
            cidade='Campinas', latitude='-22.906800', longitude='-47.062600', ativo=True,
        )
        NegocioPublico.objects.create(
            schema_name='recife', nome='Recife', nicho='barbearia',
            cidade='Recife', latitude='-8.047600', longitude='-34.877000', ativo=True,
        )

    def _schemas(self, response):
        return {n['schema_name'] for n in response.data}

    def test_raio_curto_traz_so_o_que_esta_perto(self, api):
        response = api.get('/api/sm/negocios/?lat=-23.55&lng=-46.633&raio_km=20')
        assert self._schemas(response) == {'sp_centro'}

    def test_raio_maior_alcanca_a_cidade_vizinha(self, api):
        response = api.get('/api/sm/negocios/?lat=-23.55&lng=-46.633&raio_km=120')
        assert self._schemas(response) == {'sp_centro', 'campinas'}

    def test_raio_nunca_alcanca_o_outro_lado_do_pais(self, api):
        response = api.get('/api/sm/negocios/?lat=-23.55&lng=-46.633&raio_km=200')
        assert 'recife' not in self._schemas(response)

    def test_raio_padrao_quando_nao_informado(self, api):
        response = api.get('/api/sm/negocios/?lat=-23.55&lng=-46.633')
        assert self._schemas(response) == {'sp_centro'}

    def test_sem_coordenadas_nao_filtra(self, api):
        response = api.get('/api/sm/negocios/')
        assert len(response.data) == 3

    def test_lat_sem_lng_e_ignorado(self, api):
        response = api.get('/api/sm/negocios/?lat=-23.55')
        assert len(response.data) == 3

    def test_area_combina_com_nicho(self, api):
        NegocioPublico.objects.create(
            schema_name='sp_pet', nome='SP Pet', nicho='banho_tosa',
            cidade='São Paulo', latitude='-23.551000', longitude='-46.634000', ativo=True,
        )
        response = api.get('/api/sm/negocios/?lat=-23.55&lng=-46.633&raio_km=20&nicho=banho_tosa')
        assert self._schemas(response) == {'sp_pet'}

    def test_coordenada_invalida_retorna_400(self, api):
        assert api.get('/api/sm/negocios/?lat=abc&lng=-46.6').status_code == 400

    def test_latitude_fora_do_intervalo_retorna_400(self, api):
        assert api.get('/api/sm/negocios/?lat=120&lng=-46.6').status_code == 400

    def test_raio_negativo_retorna_400(self, api):
        assert api.get('/api/sm/negocios/?lat=-23.55&lng=-46.633&raio_km=-5').status_code == 400


@pytest.mark.django_db
class TestNichosDaVitrine:
    URL = '/api/sm/negocios/nichos/'

    def test_lista_nichos_distintos_ordenados(self, api, vitrine_variada):
        response = api.get(self.URL)
        assert response.status_code == 200
        assert response.data == ['banho_tosa', 'barbearia', 'lava_rapido']

    def test_nao_repete_nicho(self, api, vitrine_variada):
        NegocioPublico.objects.create(
            schema_name='outra_barbearia', nome='Outra', nicho='barbearia',
            cidade='Recife', latitude='-23.5', longitude='-46.6', ativo=True,
        )
        response = api.get(self.URL)
        assert response.data.count('barbearia') == 1

    def test_ignora_negocio_inativo(self, api, negocio_inativo):
        response = api.get(self.URL)
        assert response.data == []

    def test_filtra_nichos_pela_cidade(self, api, vitrine_variada):
        """O modal de categorias do mapa mostra so o que existe na cidade ativa."""
        response = api.get(f'{self.URL}?cidade=Santos')
        assert response.data == ['banho_tosa']

    def test_cidade_sem_negocio_retorna_lista_vazia(self, api, vitrine_variada):
        response = api.get(f'{self.URL}?cidade=Manaus')
        assert response.data == []

    def test_endpoint_publico_sem_auth(self, api, vitrine_variada):
        assert api.get(self.URL).status_code == 200

    def test_rota_nao_e_capturada_pelo_detalhe(self, api, vitrine_variada):
        """'nichos' casaria com <schema_name> se a ordem no urlpatterns mudasse."""
        response = api.get(self.URL)
        assert isinstance(response.data, list)


# ---------------------------------------------------------------------------
# GET /api/sm/negocios/{schema}/
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestNegocioPublicoDetalhe:
    def test_retorna_o_negocio_pelo_schema(self, api, negocio):
        response = api.get(f'/api/sm/negocios/{negocio.schema_name}/')
        assert response.status_code == 200
        assert response.data['schema_name'] == negocio.schema_name

    def test_negocio_inexistente_retorna_404(self, api, db):
        response = api.get('/api/sm/negocios/nao_existe/')
        assert response.status_code == 404

    def test_negocio_inativo_retorna_404(self, api, negocio_inativo):
        response = api.get(f'/api/sm/negocios/{negocio_inativo.schema_name}/')
        assert response.status_code == 404

    def test_schema_invalido_retorna_400(self, api, db):
        response = api.get('/api/sm/negocios/Schema-Invalido/')
        assert response.status_code == 400

    def test_endpoint_publico_sem_auth(self, api, negocio):
        response = api.get(f'/api/sm/negocios/{negocio.schema_name}/')
        assert response.status_code == 200

    def test_rota_de_cidades_nao_e_capturada_pelo_detalhe(self, api, negocio):
        """A rota nova casa qualquer <schema_name>, entao 'cidades' passaria a
        cair nela se a ordem no urlpatterns estivesse errada."""
        response = api.get('/api/sm/negocios/cidades/')
        assert response.status_code == 200
        assert isinstance(response.data, list)


# ---------------------------------------------------------------------------
# GET /api/sm/negocios/{schema}/servicos/
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestServicosNegocio:
    def test_retorna_servicos_do_tenant(self, api, negocio):
        servicos_mock = [
            {'id': 1, 'nome': 'Corte', 'descricao': '', 'duracao': 30, 'preco': '50.00'},
            {'id': 2, 'nome': 'Barba', 'descricao': '', 'duracao': 20, 'preco': '30.00'},
        ]
        with patch('apps_serv.vitrine.views.CrossTenantQueryService') as MockSvc:
            MockSvc.return_value.listar_servicos.return_value = servicos_mock
            response = api.get(f'/api/sm/negocios/{negocio.schema_name}/servicos/')
        assert response.status_code == 200
        assert len(response.data) == 2

    def test_negocio_inexistente_retorna_404(self, api, db):
        response = api.get('/api/sm/negocios/schema_inexistente/servicos/')
        assert response.status_code == 404

    def test_negocio_inativo_retorna_404(self, api, negocio_inativo):
        response = api.get(f'/api/sm/negocios/{negocio_inativo.schema_name}/servicos/')
        assert response.status_code == 404

    def test_endpoint_publico_sem_auth(self, api, negocio):
        with patch('apps_serv.vitrine.views.CrossTenantQueryService') as MockSvc:
            MockSvc.return_value.listar_servicos.return_value = []
            response = api.get(f'/api/sm/negocios/{negocio.schema_name}/servicos/')
        assert response.status_code == 200


# ---------------------------------------------------------------------------
# GET /api/sm/negocios/{schema}/disponibilidade/
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestDisponibilidade:
    def test_retorna_slots_disponiveis(self, api, negocio):
        data_futura = (timezone.now() + timedelta(days=30)).strftime('%Y-%m-%d')
        slots_mock = [f'{data_futura}T09:00:00', f'{data_futura}T09:30:00']
        with patch('apps_serv.vitrine.views.CrossTenantQueryService') as MockSvc:
            MockSvc.return_value.listar_disponibilidade.return_value = slots_mock
            response = api.get(
                f'/api/sm/negocios/{negocio.schema_name}/disponibilidade/',
                {'data': data_futura, 'servico_id': 1},
            )
        assert response.status_code == 200
        assert 'slots' in response.data
        assert len(response.data['slots']) == 2

    def test_data_ausente_retorna_400(self, api, negocio):
        response = api.get(
            f'/api/sm/negocios/{negocio.schema_name}/disponibilidade/',
            {'servico_id': 1},
        )
        assert response.status_code == 400

    def test_servico_id_ausente_retorna_400(self, api, negocio):
        response = api.get(
            f'/api/sm/negocios/{negocio.schema_name}/disponibilidade/',
            {'data': '2025-07-10'},
        )
        assert response.status_code == 400

    def test_formato_de_data_invalido_retorna_400(self, api, negocio):
        response = api.get(
            f'/api/sm/negocios/{negocio.schema_name}/disponibilidade/',
            {'data': '10-07-2025', 'servico_id': 1},
        )
        assert response.status_code == 400

    def test_data_no_passado_retorna_400(self, api, negocio):
        response = api.get(
            f'/api/sm/negocios/{negocio.schema_name}/disponibilidade/',
            {'data': '2000-01-01', 'servico_id': 1},
        )
        assert response.status_code == 400

    def test_negocio_inexistente_retorna_404(self, api, db):
        data_futura = (timezone.now() + timedelta(days=30)).strftime('%Y-%m-%d')
        response = api.get(
            '/api/sm/negocios/nao_existe/disponibilidade/',
            {'data': data_futura, 'servico_id': 1},
        )
        assert response.status_code == 404


# ---------------------------------------------------------------------------
# POST /api/sm/negocios/{schema}/agendamentos/
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestCriarAgendamento:
    def test_criacao_bem_sucedida_retorna_201(self, api_autenticado, negocio):
        client, consumidor = api_autenticado
        mock_agendamento = MagicMock()
        mock_agendamento.id = 1
        mock_agendamento.negocio_nome = negocio.nome
        mock_agendamento.schema_name = negocio.schema_name
        mock_agendamento.servicos = [{'nome': 'Corte', 'duracao': 30, 'preco': 50.0}]
        mock_agendamento.data_hora = timezone.now() + timedelta(hours=2)
        mock_agendamento.duracao_total = 30
        mock_agendamento.valor_total = Decimal('50.00')
        mock_agendamento.status = 'agendado'
        mock_agendamento.checkin_realizado = False
        mock_agendamento.criado_em = timezone.now()
        mock_agendamento.agendamento_id = 10
        mock_agendamento.nicho = 'Barbearia'
        mock_agendamento.profissional_nome = ''

        with patch('apps_serv.vitrine.views.AgendamentoTenantService') as MockSvc:
            MockSvc.return_value.criar.return_value = mock_agendamento
            with patch('apps_serv.vitrine.views.AgendamentoConsumidorSerializer') as MockSer:
                MockSer.return_value.data = {'id': 1, 'status': 'agendado'}
                response = client.post(f'/api/sm/negocios/{negocio.schema_name}/agendamentos/', {
                    'servico_ids': [1],
                    'data_hora': (timezone.now() + timedelta(hours=2)).isoformat(),
                })
        assert response.status_code == 201

    def test_sem_auth_retorna_401(self, api, negocio):
        response = api.post(f'/api/sm/negocios/{negocio.schema_name}/agendamentos/', {
            'servico_ids': [1],
            'data_hora': (timezone.now() + timedelta(hours=2)).isoformat(),
        })
        assert response.status_code == 401

    def test_negocio_inexistente_retorna_404(self, api_autenticado):
        client, _ = api_autenticado
        response = client.post('/api/sm/negocios/nao_existe/agendamentos/', {
            'servico_ids': [1],
            'data_hora': (timezone.now() + timedelta(hours=2)).isoformat(),
        })
        assert response.status_code == 404

    def test_campos_obrigatorios_ausentes_retorna_400(self, api_autenticado, negocio):
        client, _ = api_autenticado
        response = client.post(f'/api/sm/negocios/{negocio.schema_name}/agendamentos/', {})
        assert response.status_code == 400

    def test_data_hora_no_passado_retorna_400(self, api_autenticado, negocio):
        client, _ = api_autenticado
        response = client.post(f'/api/sm/negocios/{negocio.schema_name}/agendamentos/', {
            'servico_ids': [1],
            'data_hora': (timezone.now() - timedelta(hours=1)).isoformat(),
        })
        assert response.status_code == 400

    def test_servico_invalido_retorna_400(self, api_autenticado, negocio):
        client, _ = api_autenticado
        with patch('apps_serv.vitrine.views.AgendamentoTenantService') as MockSvc:
            MockSvc.return_value.criar.side_effect = ValueError('Nenhum serviço válido encontrado.')
            response = client.post(f'/api/sm/negocios/{negocio.schema_name}/agendamentos/', {
                'servico_ids': [1],
                'data_hora': (timezone.now() + timedelta(hours=2)).isoformat(),
            })
        assert response.status_code == 400
        assert 'Nenhum serviço válido' in response.data['detail']


# ---------------------------------------------------------------------------
# CancelarAgendamentoService — lógica de prazo e taxa
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestCancelarAgendamentoService:
    """Testa a lógica de prazo e taxa de cancelamento sem depender do tenant schema."""

    def _criar_agendamento(self, consumidor, data_hora, duracao, valor_taxa_cancelamento=Decimal('0')):
        return consumidor.agendamentos.create(
            schema_name='fake',
            agendamento_id=1,
            negocio_nome='X',
            servicos=[],
            data_hora=data_hora,
            duracao_total=duracao,
            valor_total=Decimal('100.00'),
            valor_taxa_cancelamento=valor_taxa_cancelamento,
            status='agendado',
        )

    def _consumidor_registrado(self):
        return RegistroConsumidorService().registrar(
            nome='Teste', email='taxa@sm.com', senha='SenhaForte123!',
        )

    def test_cancela_dentro_prazo_sem_taxa(self, db):
        from apps_serv.vitrine.services import CancelarAgendamentoService
        consumidor = self._consumidor_registrado()
        # Duração 30min → prazo 6h; agendamento em 10h = dentro do prazo
        ag = self._criar_agendamento(
            consumidor, timezone.now() + timedelta(hours=10), duracao=30,
            valor_taxa_cancelamento=Decimal('20.00'),
        )

        # schema_context e Agendamento são mockados para evitar cross-schema em testes
        with patch('apps_serv.vitrine.services.schema_context'), \
             patch('apps_work.agenda.models.Agendamento'):
            resultado = CancelarAgendamentoService().cancelar(ag, consumidor)

        assert resultado['taxa'] == 0.0
        assert 'reembolso' not in resultado

    def test_cancela_fora_prazo_com_taxa_configurada_registra_pendencia(self, db):
        from apps_serv.vitrine.services import CancelarAgendamentoService
        consumidor = self._consumidor_registrado()
        # Duração 30min → prazo 6h; agendamento em 2h = fora do prazo
        ag = self._criar_agendamento(
            consumidor, timezone.now() + timedelta(hours=2), duracao=30,
            valor_taxa_cancelamento=Decimal('20.00'),
        )

        mock_cliente = MagicMock(id=1)
        with patch('apps_serv.vitrine.services.schema_context'), \
             patch('apps_work.agenda.models.Agendamento'), \
             patch('apps_work.clientes.models.Cliente') as MockCliente, \
             patch('apps_work.financeiro.services.SaldoService') as MockSaldoService:
            MockCliente.objects.filter.return_value.first.return_value = mock_cliente
            resultado = CancelarAgendamentoService().cancelar(ag, consumidor)

        assert resultado['taxa'] == 20.0
        assert 'reembolso' not in resultado
        MockSaldoService.return_value.registrar_taxa_cancelamento.assert_called_once()
        args, _kwargs = MockSaldoService.return_value.registrar_taxa_cancelamento.call_args
        assert args[0] == mock_cliente.id
        assert args[1] == Decimal('20.00')

    def test_cancela_fora_prazo_sem_taxa_configurada_nao_registra_pendencia(self, db):
        from apps_serv.vitrine.services import CancelarAgendamentoService
        consumidor = self._consumidor_registrado()
        ag = self._criar_agendamento(consumidor, timezone.now() + timedelta(hours=2), duracao=30)

        with patch('apps_serv.vitrine.services.schema_context'), \
             patch('apps_work.agenda.models.Agendamento'), \
             patch('apps_work.financeiro.services.SaldoService') as MockSaldoService:
            resultado = CancelarAgendamentoService().cancelar(ag, consumidor)

        assert resultado['taxa'] == 0.0
        MockSaldoService.return_value.registrar_taxa_cancelamento.assert_not_called()

    def test_cancela_agendamento_ja_cancelado_levanta_value_error(self, db):
        from apps_serv.vitrine.services import CancelarAgendamentoService
        consumidor = self._consumidor_registrado()
        ag = self._criar_agendamento(consumidor, timezone.now() + timedelta(hours=10), duracao=30)
        ag.status = 'cancelado'
        ag.save()

        with pytest.raises(ValueError, match='já cancelado'):
            CancelarAgendamentoService().cancelar(ag, consumidor)

    def test_cancela_agendamento_concluido_levanta_value_error(self, db):
        from apps_serv.vitrine.services import CancelarAgendamentoService
        consumidor = self._consumidor_registrado()
        ag = self._criar_agendamento(consumidor, timezone.now() + timedelta(hours=10), duracao=30)
        ag.status = 'concluido'
        ag.save()

        with pytest.raises(ValueError, match='concluído'):
            CancelarAgendamentoService().cancelar(ag, consumidor)
