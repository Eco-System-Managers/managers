import pytest
from django.contrib.auth.models import User
from datetime import datetime, timedelta, timezone
from rest_framework.test import APIClient

from apps_work.agenda.models import Agendamento, AgendamentoServico, Pagamento as PagamentoAgenda
from apps_work.clientes.models import Cliente
from apps_work.servicos.models import Servico
from apps_work.usuarios.models import Colaborador


@pytest.fixture
def client_autenticado(patch_tenant_middleware, usuario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=usuario)
    return client


@pytest.fixture
def cliente(patch_tenant_middleware):
    return Cliente.objects.create(nome='Ana Lima')


@pytest.fixture
def servico(patch_tenant_middleware):
    return Servico.objects.create(nome='Corte', duracao=30, preco='50.00')


@pytest.fixture
def colaborador(patch_tenant_middleware):
    user = User.objects.create_user(
        username='colab@email.com',
        email='colab@email.com',
        password='senha123',
        first_name='Pedro',
        last_name='Costa',
    )
    return Colaborador.objects.create(user=user, role='colaborador')


@pytest.fixture
def agendamento(patch_tenant_middleware, cliente):
    return Agendamento.objects.create(
        cliente=cliente,
        data_hora=datetime(2024, 6, 10, 9, 0, tzinfo=timezone.utc),
    )


@pytest.fixture
def agendamento_com_servico(agendamento, servico):
    AgendamentoServico.objects.create(
        agendamento=agendamento,
        servico=servico,
        preco_cobrado=servico.preco,
        desconto=0,
    )
    return agendamento


# --- AgendamentoViewSet ---

@pytest.mark.django_db
class TestAgendamentoAPI:
    def test_listar_agendamentos_retorna_200(self, client_autenticado, agendamento):
        response = client_autenticado.get('/api/agendamentos/')
        assert response.status_code == 200
        assert response.data['count'] == 1

    def test_grade_do_dia_nao_vem_paginada(self, client_autenticado, agendamento):
        """A tela monta a linha do tempo com o dia inteiro: paginar faria
        horario sumir da grade sem erro nenhum."""
        response = client_autenticado.get('/api/agendamentos/?data=2024-06-10')
        assert isinstance(response.data, list)

    def test_historico_por_cliente_vem_paginado(self, client_autenticado, cliente):
        response = client_autenticado.get(f'/api/agendamentos/?cliente={cliente.id}')
        assert set(response.data) >= {'count', 'next', 'previous', 'results'}

    def test_historico_por_cliente_traz_no_maximo_vinte(self, client_autenticado, cliente):
        for hora in range(25):
            Agendamento.objects.create(
                cliente=cliente,
                data_hora=datetime(2024, 6, 10, 0, 0, tzinfo=timezone.utc) + timedelta(hours=hora),
            )
        response = client_autenticado.get(f'/api/agendamentos/?cliente={cliente.id}')
        assert response.data['count'] == 25
        assert len(response.data['results']) == 20
        assert response.data['next'] is not None

    def test_dia_cheio_sai_inteiro_mesmo_passando_de_vinte(self, client_autenticado, cliente):
        """Negocio com varios colaboradores passa de 20 agendamentos num dia.

        Meia em meia hora a partir de 12:00 UTC (09:00 em Sao_Paulo), para os 25
        caberem no mesmo dia local — `data_hora__date` filtra pela data local.
        """
        for i in range(25):
            Agendamento.objects.create(
                cliente=cliente,
                data_hora=datetime(2024, 6, 10, 12, 0, tzinfo=timezone.utc) + timedelta(minutes=30 * i),
            )
        response = client_autenticado.get('/api/agendamentos/?data=2024-06-10')
        assert len(response.data) == 25

    def test_criar_agendamento_retorna_201(self, client_autenticado, cliente):
        payload = {'cliente': cliente.id, 'data_hora': '2024-06-15T10:00:00Z'}
        response = client_autenticado.post('/api/agendamentos/', payload)
        assert response.status_code == 201
        assert response.data['cliente'] == cliente.id

    def test_criar_com_servico_cria_agendamento_servico(self, client_autenticado, cliente, servico):
        payload = {
            'cliente': cliente.id,
            'data_hora': '2024-06-15T10:00:00Z',
            'servico_id': servico.id,
        }
        response = client_autenticado.post('/api/agendamentos/', payload)
        assert response.status_code == 201
        assert AgendamentoServico.objects.filter(agendamento_id=response.data['id']).count() == 1

    def test_criar_com_servico_inexistente_ignora_e_cria_sem_servico(self, client_autenticado, cliente):
        payload = {
            'cliente': cliente.id,
            'data_hora': '2024-06-15T10:00:00Z',
            'servico_id': 99999,
        }
        response = client_autenticado.post('/api/agendamentos/', payload)
        assert response.status_code == 201
        assert AgendamentoServico.objects.filter(agendamento_id=response.data['id']).count() == 0

    def test_detalhar_agendamento_retorna_200(self, client_autenticado, agendamento):
        response = client_autenticado.get(f'/api/agendamentos/{agendamento.id}/')
        assert response.status_code == 200
        assert response.data['id'] == agendamento.id

    def test_atualizar_status_retorna_200(self, client_autenticado, agendamento):
        response = client_autenticado.patch(f'/api/agendamentos/{agendamento.id}/', {'status': 'confirmado'})
        assert response.status_code == 200
        assert response.data['status'] == 'confirmado'

    def test_deletar_agendamento_retorna_204(self, client_autenticado, agendamento):
        response = client_autenticado.delete(f'/api/agendamentos/{agendamento.id}/')
        assert response.status_code == 204
        assert Agendamento.objects.filter(pk=agendamento.pk).count() == 0

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/agendamentos/')
        assert response.status_code == 401

    def test_filtrar_por_data_retorna_apenas_do_dia(self, client_autenticado, cliente):
        Agendamento.objects.create(cliente=cliente, data_hora=datetime(2024, 6, 10, 9, 0, tzinfo=timezone.utc))
        Agendamento.objects.create(cliente=cliente, data_hora=datetime(2024, 6, 11, 9, 0, tzinfo=timezone.utc))
        response = client_autenticado.get('/api/agendamentos/?data=2024-06-10')
        assert response.status_code == 200
        assert len(response.data) == 1

    def test_filtrar_por_colaborador_retorna_do_colaborador(self, client_autenticado, cliente, colaborador):
        Agendamento.objects.create(cliente=cliente, data_hora=datetime(2024, 6, 10, 9, 0, tzinfo=timezone.utc), colaborador=colaborador)
        Agendamento.objects.create(cliente=cliente, data_hora=datetime(2024, 6, 10, 10, 0, tzinfo=timezone.utc))
        response = client_autenticado.get(f'/api/agendamentos/?colaborador={colaborador.id}')
        assert response.status_code == 200
        assert response.data['count'] == 1
        assert response.data['results'][0]['colaborador'] == colaborador.id

    def test_listar_exclui_agendamentos_cancelados(self, client_autenticado, cliente):
        Agendamento.objects.create(
            cliente=cliente,
            data_hora=datetime(2024, 6, 10, 9, 0, tzinfo=timezone.utc),
            status='cancelado',
        )
        response = client_autenticado.get('/api/agendamentos/')
        assert response.status_code == 200
        assert response.data['count'] == 0

    def test_cancelado_nao_aparece_junto_com_agendados(self, client_autenticado, cliente):
        Agendamento.objects.create(cliente=cliente, data_hora=datetime(2024, 6, 10, 9, 0, tzinfo=timezone.utc), status='agendado')
        Agendamento.objects.create(cliente=cliente, data_hora=datetime(2024, 6, 10, 10, 0, tzinfo=timezone.utc), status='cancelado')
        response = client_autenticado.get('/api/agendamentos/')
        assert response.status_code == 200
        assert response.data['count'] == 1
        assert response.data['results'][0]['status'] == 'agendado'

    def test_filtrar_por_cliente_retorna_apenas_do_cliente(self, client_autenticado, cliente):
        outro_cliente = Cliente.objects.create(nome='João Souza')
        Agendamento.objects.create(cliente=cliente, data_hora=datetime(2024, 6, 10, 9, 0, tzinfo=timezone.utc))
        Agendamento.objects.create(cliente=outro_cliente, data_hora=datetime(2024, 6, 10, 10, 0, tzinfo=timezone.utc))
        response = client_autenticado.get(f'/api/agendamentos/?cliente={cliente.id}')
        assert response.status_code == 200
        assert response.data['count'] == 1
        assert response.data['results'][0]['cliente'] == cliente.id

    def test_filtrar_por_cliente_nao_retorna_cancelados(self, client_autenticado, cliente):
        Agendamento.objects.create(cliente=cliente, data_hora=datetime(2024, 6, 10, 9, 0, tzinfo=timezone.utc), status='cancelado')
        response = client_autenticado.get(f'/api/agendamentos/?cliente={cliente.id}')
        assert response.status_code == 200
        assert response.data['count'] == 0

    def test_listar_retorna_campos_nested(self, client_autenticado, agendamento_com_servico):
        response = client_autenticado.get('/api/agendamentos/')
        assert response.status_code == 200
        data = response.data['results'][0]
        assert data['cliente_nome'] == 'Ana Lima'
        assert data['colaborador_nome'] is None
        assert isinstance(data['servicos'], list)
        assert len(data['servicos']) == 1
        assert data['servicos'][0]['servico_nome'] == 'Corte'


@pytest.mark.django_db
class TestAgendamentoConflitoHorario:
    def test_criar_em_horario_sobreposto_do_mesmo_colaborador_retorna_400(self, client_autenticado, cliente, servico, colaborador):
        Agendamento.objects.create(
            cliente=cliente, colaborador=colaborador,
            data_hora=datetime(2024, 6, 15, 10, 0, tzinfo=timezone.utc),
        )
        payload = {
            'cliente': cliente.id, 'colaborador': colaborador.id,
            'data_hora': '2024-06-15T10:15:00Z', 'servico_id': servico.id,
        }
        response = client_autenticado.post('/api/agendamentos/', payload)
        assert response.status_code == 400
        assert response.data['code'] == 'horario_conflito'

    def test_criar_logo_apos_o_fim_do_anterior_nao_conflita(self, client_autenticado, cliente, servico, colaborador):
        anterior = Agendamento.objects.create(
            cliente=cliente, colaborador=colaborador,
            data_hora=datetime(2024, 6, 15, 10, 0, tzinfo=timezone.utc),
        )
        AgendamentoServico.objects.create(
            agendamento=anterior, servico=servico, preco_cobrado=servico.preco, desconto=0,
        )
        payload = {
            'cliente': cliente.id, 'colaborador': colaborador.id,
            'data_hora': '2024-06-15T10:30:00Z',
        }
        response = client_autenticado.post('/api/agendamentos/', payload)
        assert response.status_code == 201

    def test_criar_sem_colaborador_nao_verifica_conflito(self, client_autenticado, cliente, colaborador):
        Agendamento.objects.create(
            cliente=cliente, colaborador=colaborador,
            data_hora=datetime(2024, 6, 15, 10, 0, tzinfo=timezone.utc),
        )
        payload = {'cliente': cliente.id, 'data_hora': '2024-06-15T10:15:00Z'}
        response = client_autenticado.post('/api/agendamentos/', payload)
        assert response.status_code == 201

    def test_criar_para_colaborador_diferente_nao_conflita(self, client_autenticado, cliente, colaborador):
        from django.contrib.auth.models import User
        Agendamento.objects.create(
            cliente=cliente, colaborador=colaborador,
            data_hora=datetime(2024, 6, 15, 10, 0, tzinfo=timezone.utc),
        )
        outro_user = User.objects.create_user(username='outro@email.com', email='outro@email.com', password='senha123')
        outro_colaborador = Colaborador.objects.create(user=outro_user, role='colaborador')
        payload = {
            'cliente': cliente.id, 'colaborador': outro_colaborador.id,
            'data_hora': '2024-06-15T10:15:00Z',
        }
        response = client_autenticado.post('/api/agendamentos/', payload)
        assert response.status_code == 201

    def test_atualizar_para_horario_sobreposto_retorna_400(self, client_autenticado, cliente, colaborador):
        Agendamento.objects.create(
            cliente=cliente, colaborador=colaborador,
            data_hora=datetime(2024, 6, 15, 10, 0, tzinfo=timezone.utc),
        )
        outro = Agendamento.objects.create(
            cliente=cliente, colaborador=colaborador,
            data_hora=datetime(2024, 6, 15, 14, 0, tzinfo=timezone.utc),
        )
        response = client_autenticado.patch(f'/api/agendamentos/{outro.id}/', {'data_hora': '2024-06-15T10:15:00Z'})
        assert response.status_code == 400
        assert response.data['code'] == 'horario_conflito'

    def test_atualizar_mantendo_proprio_horario_nao_conflita_consigo_mesmo(self, client_autenticado, cliente, colaborador):
        agendamento = Agendamento.objects.create(
            cliente=cliente, colaborador=colaborador,
            data_hora=datetime(2024, 6, 15, 10, 0, tzinfo=timezone.utc),
        )
        response = client_autenticado.patch(f'/api/agendamentos/{agendamento.id}/', {'status': 'confirmado'})
        assert response.status_code == 200

    def test_criar_em_dia_diferente_no_mesmo_horario_nao_conflita(self, client_autenticado, cliente, colaborador):
        Agendamento.objects.create(
            cliente=cliente, colaborador=colaborador,
            data_hora=datetime(2024, 6, 15, 10, 0, tzinfo=timezone.utc),
        )
        payload = {
            'cliente': cliente.id, 'colaborador': colaborador.id,
            'data_hora': '2024-06-16T10:00:00Z',
        }
        response = client_autenticado.post('/api/agendamentos/', payload)
        assert response.status_code == 201


@pytest.mark.django_db
class TestAgendamentoCobrar:
    def test_cobrar_sem_pagamentos_retorna_400(self, client_autenticado, agendamento_com_servico):
        response = client_autenticado.post(
            f'/api/agendamentos/{agendamento_com_servico.pk}/cobrar/',
            {'desconto': '0.00', 'pagamentos': []},
            format='json',
        )
        assert response.status_code == 400
        assert response.data['code'] == 'sem_pagamentos'

    def test_cobrar_com_total_correto_retorna_200_e_status_concluido(self, client_autenticado, agendamento_com_servico):
        payload = {
            'desconto': '0.00',
            'pagamentos': [{'forma': 'dinheiro', 'valor': '50.00'}],
        }
        response = client_autenticado.post(
            f'/api/agendamentos/{agendamento_com_servico.pk}/cobrar/',
            payload,
            format='json',
        )
        assert response.status_code == 200
        assert response.data['status'] == 'concluido'

    def test_cobrar_com_total_incorreto_retorna_400(self, client_autenticado, agendamento_com_servico):
        payload = {
            'desconto': '0.00',
            'pagamentos': [{'forma': 'dinheiro', 'valor': '10.00'}],
        }
        response = client_autenticado.post(
            f'/api/agendamentos/{agendamento_com_servico.pk}/cobrar/',
            payload,
            format='json',
        )
        assert response.status_code == 400
        assert response.data['code'] == 'soma_invalida'


@pytest.mark.django_db
class TestAgendaModelStr:
    def test_str_agendamento_servico(self, agendamento, servico):
        ag_serv = AgendamentoServico.objects.create(
            agendamento=agendamento, servico=servico, preco_cobrado='50.00', desconto=0
        )
        assert servico.nome in str(ag_serv)

    def test_str_pagamento_agenda(self, agendamento):
        pagamento = PagamentoAgenda.objects.create(
            agendamento=agendamento, forma='dinheiro', valor='50.00'
        )
        assert 'dinheiro' in str(pagamento)
        assert 'R$50.00' in str(pagamento)
