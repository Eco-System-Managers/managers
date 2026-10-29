import pytest
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from apps_work.empresa.models import EmpresaConfig
from apps_work.servicos.models import Servico
from apps_work.usuarios.models import Colaborador


@pytest.fixture
def client_autenticado(patch_tenant_middleware, proprietario, config):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def config(patch_tenant_middleware):
    """Todo serviço fica num dos nichos do negócio; com um nicho só, é ele."""
    return EmpresaConfig.objects.create(pk=1, nichos=['cabeleireiro'])


@pytest.fixture
def servico(patch_tenant_middleware):
    return Servico.objects.create(nome='Corte', nicho='cabeleireiro', duracao=30, preco='50.00')


@pytest.fixture
def colaborador_user(patch_tenant_middleware):
    user = User.objects.create_user(
        username='colab@email.com', email='colab@email.com', password='senha123',
        first_name='Maria', last_name='Souza',
    )
    return Colaborador.objects.create(user=user, funcao='Cabeleireira')


@pytest.mark.django_db
class TestServicoAPI:
    def test_listar_servicos(self, client_autenticado, servico):
        response = client_autenticado.get('/api/v1/servicos/')
        assert response.status_code == 200
        assert len(response.data['results']) == 1

    def test_criar_servico(self, client_autenticado):
        payload = {'nome': 'Escova', 'duracao': 45, 'preco': '35.00'}
        response = client_autenticado.post('/api/v1/servicos/', payload)
        assert response.status_code == 201
        assert response.data['nome'] == 'Escova'

    def test_detalhar_servico(self, client_autenticado, servico):
        response = client_autenticado.get(f'/api/v1/servicos/{servico.id}/')
        assert response.status_code == 200
        assert response.data['nome'] == servico.nome

    def test_atualizar_servico(self, client_autenticado, servico):
        response = client_autenticado.patch(f'/api/v1/servicos/{servico.id}/', {'preco': '60.00'})
        assert response.status_code == 200
        assert response.data['preco'] == '60.00'

    def test_deletar_servico(self, client_autenticado, servico):
        response = client_autenticado.delete(f'/api/v1/servicos/{servico.id}/')
        assert response.status_code == 204
        assert Servico.objects.filter(id=servico.id).count() == 0

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware, servico):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/v1/servicos/')
        assert response.status_code == 401

    def test_filtro_ativo(self, client_autenticado, servico):
        Servico.objects.create(nome='Inativo', duracao=30, preco='20.00', ativo=False)
        response = client_autenticado.get('/api/v1/servicos/?ativo=true')
        assert response.status_code == 200
        assert all(s['ativo'] for s in response.data['results'])

    def test_preco_zero_retorna_400(self, client_autenticado):
        payload = {'nome': 'Teste', 'duracao': 30, 'preco': '0.00'}
        response = client_autenticado.post('/api/v1/servicos/', payload)
        assert response.status_code == 400

    def test_duracao_zero_retorna_400(self, client_autenticado):
        payload = {'nome': 'Teste', 'duracao': 0, 'preco': '50.00'}
        response = client_autenticado.post('/api/v1/servicos/', payload)
        assert response.status_code == 400

    def test_duracao_acima_de_360_retorna_400(self, client_autenticado):
        payload = {'nome': 'Teste', 'duracao': 361, 'preco': '50.00'}
        response = client_autenticado.post('/api/v1/servicos/', payload)
        assert response.status_code == 400

    def test_buscar_servico_por_nome_filtra_resultado(self, client_autenticado, servico):
        Servico.objects.create(nome='Manicure', duracao=30, preco='25.00')
        response = client_autenticado.get('/api/v1/servicos/?search=Corte')
        assert response.status_code == 200
        assert len(response.data['results']) == 1
        assert response.data['results'][0]['nome'] == 'Corte'


@pytest.mark.django_db
class TestServicoColaboradores:
    def test_criar_servico_com_colaboradores(self, client_autenticado, colaborador_user):
        payload = {'nome': 'Escova', 'duracao': 45, 'preco': '50.00', 'colaboradores': [colaborador_user.id]}
        response = client_autenticado.post('/api/v1/servicos/', payload)
        assert response.status_code == 201
        assert colaborador_user.id in response.data['colaboradores']

    def test_filtro_por_colaborador_retorna_apenas_servicos_vinculados(self, client_autenticado, colaborador_user):
        s_vinculado = Servico.objects.create(nome='Escova', duracao=45, preco='50.00')
        s_vinculado.colaboradores.add(colaborador_user)
        Servico.objects.create(nome='Corte', duracao=30, preco='40.00')

        response = client_autenticado.get(f'/api/v1/servicos/?colaborador={colaborador_user.id}')
        assert response.status_code == 200
        assert len(response.data['results']) == 1
        assert response.data['results'][0]['nome'] == 'Escova'

    def test_filtro_por_colaborador_sem_vinculo_retorna_lista_vazia(self, client_autenticado, colaborador_user):
        Servico.objects.create(nome='Corte', duracao=30, preco='40.00')
        response = client_autenticado.get(f'/api/v1/servicos/?colaborador={colaborador_user.id}')
        assert response.status_code == 200
        assert len(response.data['results']) == 0

    def test_desassociar_colaborador_do_servico(self, client_autenticado, colaborador_user):
        servico = Servico.objects.create(nome='Escova', duracao=45, preco='50.00')
        servico.colaboradores.add(colaborador_user)
        response = client_autenticado.patch(f'/api/v1/servicos/{servico.id}/', {'colaboradores': []}, format='json')
        assert response.status_code == 200
        assert response.data['colaboradores'] == []

    def test_colaborador_inativo_nao_aparece_na_resposta_do_servico(self, client_autenticado, colaborador_user):
        servico = Servico.objects.create(nome='Escova', duracao=45, preco='50.00')
        servico.colaboradores.add(colaborador_user)
        colaborador_user.ativo = False
        colaborador_user.save(update_fields=['ativo'])

        response = client_autenticado.get(f'/api/v1/servicos/{servico.id}/')
        assert response.status_code == 200
        assert colaborador_user.id not in response.data['colaboradores']

    def test_criar_servico_com_colaborador_inativo_retorna_400(self, client_autenticado, colaborador_user):
        colaborador_user.ativo = False
        colaborador_user.save(update_fields=['ativo'])

        payload = {'nome': 'Corte', 'duracao': 30, 'preco': '50.00', 'colaboradores': [colaborador_user.id]}
        response = client_autenticado.post('/api/v1/servicos/', payload)
        assert response.status_code == 400


@pytest.mark.django_db
class TestServicoNicho:
    """O serviço fica numa pasta: um dos nichos do negócio."""

    URL = '/api/v1/servicos/'
    PAYLOAD = {'nome': 'Escova', 'duracao': 45, 'preco': '35.00'}

    def test_com_um_nicho_so_o_servico_fica_nele(self, client_autenticado):
        response = client_autenticado.post(self.URL, self.PAYLOAD)
        assert response.status_code == 201
        assert response.data['nicho'] == 'cabeleireiro'

    def test_com_varios_nichos_o_nicho_e_obrigatorio(self, client_autenticado, config):
        config.nichos = ['cabeleireiro', 'manicure']
        config.save()
        response = client_autenticado.post(self.URL, self.PAYLOAD)
        assert response.status_code == 400
        assert response.data['code'] == 'nicho_obrigatorio'

    def test_com_varios_nichos_aceita_um_deles(self, client_autenticado, config):
        config.nichos = ['cabeleireiro', 'manicure']
        config.save()
        response = client_autenticado.post(self.URL, {**self.PAYLOAD, 'nicho': 'manicure'})
        assert response.status_code == 201
        assert response.data['nicho'] == 'manicure'

    def test_nicho_que_o_negocio_nao_atende_e_recusado(self, client_autenticado):
        response = client_autenticado.post(self.URL, {**self.PAYLOAD, 'nicho': 'massagem'})
        assert response.status_code == 400
        assert response.data['code'] == 'nicho_fora_do_negocio'

    def test_inativo_de_nicho_removido_continua_editavel(self, client_autenticado):
        servico = Servico.objects.create(nome='Pé e mão', nicho='manicure', duracao=60, preco='40.00', ativo=False)
        response = client_autenticado.patch(f'{self.URL}{servico.id}/', {'nome': 'Pé e mão completo'}, format='json')
        assert response.status_code == 200

    def test_reativar_em_nicho_removido_e_recusado(self, client_autenticado):
        servico = Servico.objects.create(nome='Pé e mão', nicho='manicure', duracao=60, preco='40.00', ativo=False)
        response = client_autenticado.patch(f'{self.URL}{servico.id}/', {'ativo': True}, format='json')
        assert response.status_code == 400
        assert response.data['code'] == 'nicho_fora_do_negocio'

    def test_reativar_trocando_para_um_nicho_atual(self, client_autenticado):
        servico = Servico.objects.create(nome='Pé e mão', nicho='manicure', duracao=60, preco='40.00', ativo=False)
        response = client_autenticado.patch(
            f'{self.URL}{servico.id}/', {'ativo': True, 'nicho': 'cabeleireiro'}, format='json',
        )
        assert response.status_code == 200
        assert response.data['ativo'] is True
