"""Controle de acesso do B2B (issue #3).

Os testes daqui usam token real, e não `force_authenticate`: o vínculo com o
tenant é verificado na TenantJWTAuthentication, e o `force_authenticate` pula a
autenticação inteira.
"""
import pytest
from datetime import timedelta
from django.contrib.auth.models import User
from django.db import connection
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps_work.usuarios.models import Colaborador, ConviteColaborador
from tenants.models import Tenant, Membro


def _cliente_com_token(user, schema_name='test_empresa'):
    refresh = RefreshToken.for_user(user)
    if schema_name is not None:
        refresh['schema_name'] = schema_name
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {str(refresh.access_token)}')
    return client


@pytest.fixture
def dono(patch_tenant_middleware, proprietario):
    Colaborador.objects.create(user=proprietario)
    return proprietario


@pytest.fixture
def colaborador(patch_tenant_middleware, tenant):
    user = User.objects.create_user(
        username='colab@email.com', email='colab@email.com', password='SenhaForte123!',
    )
    Membro.objects.create(user=user, tenant=tenant, papel='colaborador')
    return Colaborador.objects.create(user=user)


@pytest.fixture
def outra_empresa(patch_tenant_middleware, tenant):
    # Só a linha do tenant: o schema não é necessário para testar o vínculo.
    connection.set_schema_to_public()
    outra = Tenant(schema_name='outra_empresa', nome='Outra Empresa')
    outra.auto_create_schema = False
    outra.save()
    connection.set_tenant(tenant)
    return outra


@pytest.mark.django_db
class TestEscaladaParaProprietario:
    def test_colaborador_nao_se_promove_via_put(self, colaborador):
        client = _cliente_com_token(colaborador.user)
        response = client.put(
            f'/api/v1/colaboradores/{colaborador.id}/',
            {'role': 'proprietario', 'funcao': 'Dono'},
        )
        assert response.status_code == 403
        colaborador.refresh_from_db()
        assert Membro.objects.get(user=colaborador.user).papel == 'colaborador'

    def test_colaborador_nao_edita_via_patch(self, colaborador):
        client = _cliente_com_token(colaborador.user)
        response = client.patch(f'/api/v1/colaboradores/{colaborador.id}/', {'role': 'proprietario'})
        assert response.status_code == 403

    def test_colaborador_nao_desativa_o_dono_via_put(self, colaborador, dono):
        client = _cliente_com_token(colaborador.user)
        response = client.put(f'/api/v1/colaboradores/{dono.colaborador.id}/', {'ativo': False})
        assert response.status_code == 403
        dono.refresh_from_db()
        assert dono.is_active is True

    def test_colaborador_nao_desativa_o_dono_via_action(self, colaborador, dono):
        client = _cliente_com_token(colaborador.user)
        response = client.post(f'/api/v1/colaboradores/{dono.colaborador.id}/desativar/')
        assert response.status_code == 403
        dono.refresh_from_db()
        assert dono.is_active is True

    def test_colaborador_continua_listando_a_equipe(self, colaborador):
        client = _cliente_com_token(colaborador.user)
        assert client.get('/api/v1/colaboradores/').status_code == 200

    def test_proprietario_edita_funcao_com_token_real(self, dono, colaborador):
        client = _cliente_com_token(dono)
        response = client.patch(f'/api/v1/colaboradores/{colaborador.id}/', {'funcao': 'Barbeiro'})
        assert response.status_code == 200
        colaborador.refresh_from_db()
        assert colaborador.funcao == 'Barbeiro'


@pytest.mark.django_db
class TestProprietarioNaoSeTrancaParaFora:
    def test_nao_desativa_a_si_mesmo(self, dono):
        client = _cliente_com_token(dono)
        response = client.post(f'/api/v1/colaboradores/{dono.colaborador.id}/desativar/')
        assert response.status_code == 400
        dono.refresh_from_db()
        assert dono.is_active is True

    def test_nao_desativa_a_si_mesmo_via_delete(self, dono):
        client = _cliente_com_token(dono)
        response = client.delete(f'/api/v1/colaboradores/{dono.colaborador.id}/')
        assert response.status_code == 400
        dono.refresh_from_db()
        assert dono.is_active is True

    def test_nao_remove_a_si_mesmo(self, dono):
        client = _cliente_com_token(dono)
        response = client.delete(f'/api/v1/colaboradores/{dono.colaborador.id}/remover/')
        assert response.status_code == 400
        assert User.objects.filter(pk=dono.pk).exists()

    def test_nao_desativa_outro_proprietario(self, dono, tenant):
        socio = User.objects.create_user(username='socio@email.com', email='socio@email.com', password='x')
        Membro.objects.create(user=socio, tenant=tenant, papel='proprietario')
        colab_socio = Colaborador.objects.create(user=socio)

        client = _cliente_com_token(dono)
        response = client.post(f'/api/v1/colaboradores/{colab_socio.id}/desativar/')
        assert response.status_code == 400
        socio.refresh_from_db()
        assert socio.is_active is True


@pytest.mark.django_db
class TestAcessoCruzadoEntreTenants:
    def test_token_de_outro_tenant_e_recusado(self, outra_empresa):
        # Usuário da outra empresa, com o próprio token, chegando pelo Host
        # desta empresa.
        user = User.objects.create_user(username='a@email.com', email='a@email.com', password='x')
        Membro.objects.create(user=user, tenant=outra_empresa, papel='proprietario')

        client = _cliente_com_token(user, schema_name='outra_empresa')
        assert client.get('/api/v1/colaboradores/').status_code == 401
        assert client.get('/api/v1/servicos/').status_code == 401

    def test_usuario_sem_vinculo_com_o_tenant_e_recusado(self, outra_empresa):
        # Mesmo com o schema_name do token batendo, sem Membro não entra.
        user = User.objects.create_user(username='b@email.com', email='b@email.com', password='x')
        Membro.objects.create(user=user, tenant=outra_empresa, papel='proprietario')

        client = _cliente_com_token(user, schema_name='test_empresa')
        assert client.get('/api/v1/colaboradores/').status_code == 401

    def test_token_sem_schema_e_recusado(self, patch_tenant_middleware, proprietario):
        client = _cliente_com_token(proprietario, schema_name=None)
        assert client.get('/api/v1/colaboradores/').status_code == 401

    def test_proprietario_de_outro_tenant_nao_e_proprietario_aqui(self, outra_empresa, colaborador):
        # Dono de outra empresa não vira dono desta por ter um papel lá.
        Membro.objects.filter(user=colaborador.user).delete()
        Membro.objects.create(user=colaborador.user, tenant=outra_empresa, papel='proprietario')

        client = _cliente_com_token(colaborador.user)
        response = client.post('/api/v1/servicos/', {'nome': 'Corte', 'duracao': 30, 'preco': '50.00'})
        assert response.status_code == 401


@pytest.mark.django_db
class TestConvitePorIdSequencial:
    def test_anonimo_nao_aceita_convite_por_id(self, patch_tenant_middleware):
        convite = ConviteColaborador.objects.create(
            nome='Ana', email='ana@email.com', expira_em=timezone.now() + timedelta(days=2),
        )
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'

        response = client.post(f'/api/v1/convites/{convite.pk}/aceitar/', {'senha': 'SenhaForte@2024!'})

        assert response.status_code == 404
        convite.refresh_from_db()
        assert convite.aceito is False
        assert not User.objects.filter(email='ana@email.com').exists()
