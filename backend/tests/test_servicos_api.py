import pytest
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from apps_work.servicos.models import Servico
from apps_work.usuarios.models import Colaborador


@pytest.fixture
def client_autenticado(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def servico(patch_tenant_middleware):
    return Servico.objects.create(nome='Corte', duracao=30, preco='50.00')


@pytest.fixture
def colaborador_user(patch_tenant_middleware):
    user = User.objects.create_user(
        username='colab@email.com', email='colab@email.com', password='senha123',
        first_name='Maria', last_name='Souza',
    )
    return Colaborador.objects.create(user=user, funcao='Cabeleireira', role='colaborador')


@pytest.mark.django_db
class TestServicoAPI:
    def test_listar_servicos(self, client_autenticado, servico):
        response = client_autenticado.get('/api/servicos/')
        assert response.status_code == 200
        assert len(response.data['results']) == 1

    def test_criar_servico(self, client_autenticado):
        payload = {'nome': 'Escova', 'duracao': 45, 'preco': '35.00'}
        response = client_autenticado.post('/api/servicos/', payload)
        assert response.status_code == 201
        assert response.data['nome'] == 'Escova'

    def test_detalhar_servico(self, client_autenticado, servico):
        response = client_autenticado.get(f'/api/servicos/{servico.id}/')
        assert response.status_code == 200
        assert response.data['nome'] == servico.nome

    def test_atualizar_servico(self, client_autenticado, servico):
        response = client_autenticado.patch(f'/api/servicos/{servico.id}/', {'preco': '60.00'})
        assert response.status_code == 200
        assert response.data['preco'] == '60.00'

    def test_deletar_servico(self, client_autenticado, servico):
        response = client_autenticado.delete(f'/api/servicos/{servico.id}/')
        assert response.status_code == 204
        assert Servico.objects.filter(id=servico.id).count() == 0

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware, servico):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/servicos/')
        assert response.status_code == 401

    def test_filtro_ativo(self, client_autenticado, servico):
        Servico.objects.create(nome='Inativo', duracao=30, preco='20.00', ativo=False)
        response = client_autenticado.get('/api/servicos/?ativo=true')
        assert response.status_code == 200
        assert all(s['ativo'] for s in response.data['results'])

    def test_preco_zero_retorna_400(self, client_autenticado):
        payload = {'nome': 'Teste', 'duracao': 30, 'preco': '0.00'}
        response = client_autenticado.post('/api/servicos/', payload)
        assert response.status_code == 400

    def test_duracao_zero_retorna_400(self, client_autenticado):
        payload = {'nome': 'Teste', 'duracao': 0, 'preco': '50.00'}
        response = client_autenticado.post('/api/servicos/', payload)
        assert response.status_code == 400

    def test_duracao_acima_de_360_retorna_400(self, client_autenticado):
        payload = {'nome': 'Teste', 'duracao': 361, 'preco': '50.00'}
        response = client_autenticado.post('/api/servicos/', payload)
        assert response.status_code == 400

    def test_buscar_servico_por_nome_filtra_resultado(self, client_autenticado, servico):
        Servico.objects.create(nome='Manicure', duracao=30, preco='25.00')
        response = client_autenticado.get('/api/servicos/?search=Corte')
        assert response.status_code == 200
        assert len(response.data['results']) == 1
        assert response.data['results'][0]['nome'] == 'Corte'


@pytest.mark.django_db
class TestServicoColaboradores:
    def test_criar_servico_com_colaboradores(self, client_autenticado, colaborador_user):
        payload = {'nome': 'Escova', 'duracao': 45, 'preco': '50.00', 'colaboradores': [colaborador_user.id]}
        response = client_autenticado.post('/api/servicos/', payload)
        assert response.status_code == 201
        assert colaborador_user.id in response.data['colaboradores']

    def test_filtro_por_colaborador_retorna_apenas_servicos_vinculados(self, client_autenticado, colaborador_user):
        s_vinculado = Servico.objects.create(nome='Escova', duracao=45, preco='50.00')
        s_vinculado.colaboradores.add(colaborador_user)
        Servico.objects.create(nome='Corte', duracao=30, preco='40.00')

        response = client_autenticado.get(f'/api/servicos/?colaborador={colaborador_user.id}')
        assert response.status_code == 200
        assert len(response.data['results']) == 1
        assert response.data['results'][0]['nome'] == 'Escova'

    def test_filtro_por_colaborador_sem_vinculo_retorna_lista_vazia(self, client_autenticado, colaborador_user):
        Servico.objects.create(nome='Corte', duracao=30, preco='40.00')
        response = client_autenticado.get(f'/api/servicos/?colaborador={colaborador_user.id}')
        assert response.status_code == 200
        assert len(response.data['results']) == 0

    def test_desassociar_colaborador_do_servico(self, client_autenticado, colaborador_user):
        servico = Servico.objects.create(nome='Escova', duracao=45, preco='50.00')
        servico.colaboradores.add(colaborador_user)
        response = client_autenticado.patch(f'/api/servicos/{servico.id}/', {'colaboradores': []}, format='json')
        assert response.status_code == 200
        assert response.data['colaboradores'] == []

    def test_colaborador_inativo_nao_aparece_na_resposta_do_servico(self, client_autenticado, colaborador_user):
        servico = Servico.objects.create(nome='Escova', duracao=45, preco='50.00')
        servico.colaboradores.add(colaborador_user)
        colaborador_user.ativo = False
        colaborador_user.save(update_fields=['ativo'])

        response = client_autenticado.get(f'/api/servicos/{servico.id}/')
        assert response.status_code == 200
        assert colaborador_user.id not in response.data['colaboradores']

    def test_criar_servico_com_colaborador_inativo_retorna_400(self, client_autenticado, colaborador_user):
        colaborador_user.ativo = False
        colaborador_user.save(update_fields=['ativo'])

        payload = {'nome': 'Corte', 'duracao': 30, 'preco': '50.00', 'colaboradores': [colaborador_user.id]}
        response = client_autenticado.post('/api/servicos/', payload)
        assert response.status_code == 400
