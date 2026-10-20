import pytest
from datetime import date, timedelta
from unittest.mock import patch

from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APIClient

from apps_work.autenticacao.models import CodigoRecuperacao
from tenants.models import Domain, Tenant, Membro


@pytest.fixture
def api(patch_tenant_middleware):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    return client


@pytest.fixture
def user_auth(db):
    return User.objects.create_user(
        username='auth@teste.com',
        email='auth@teste.com',
        password='SenhaForte123!',
        first_name='Auth',
    )


@pytest.fixture
def user_com_tenant(db):
    from django.db import connection

    connection.set_schema_to_public()
    tenant = Tenant.objects.create(schema_name='login_test', nome='Login Test')
    connection.set_schema_to_public()
    Domain.objects.create(domain='login-test.localhost', tenant=tenant, is_primary=True)
    user = User.objects.create_user(
        username='login@teste.com',
        email='login@teste.com',
        password='SenhaForte123!',
        first_name='Login',
    )
    Membro.objects.create(user=user, tenant=tenant, papel='proprietario')
    return user, tenant


@pytest.fixture
def codigo_recuperacao(user_auth):
    return CodigoRecuperacao.emitir(user_auth, '12345678')[0]


@pytest.mark.django_db
class TestCadastro:
    def test_cria_usuario_e_retorna_tokens(self, api):
        payload = {
            'nome_empresa': 'Salão Teste',
            'nome': 'Ana Silva',
            'email': 'ana@teste.com',
            'senha': 'SenhaForte123!',
        }
        response = api.post('/api/v1/auth/cadastro/', payload)
        assert response.status_code == 201
        assert 'access' in response.data
        # Web: o refresh vai só no cookie httpOnly, nunca no corpo.
        assert 'refresh' not in response.data
        assert 'schema_name' in response.data
        assert response.data['empresa'] == 'Salão Teste'
        assert response.cookies.get('refresh_token') is not None

    def test_email_duplicado_retorna_400(self, api, user_auth):
        payload = {
            'nome_empresa': 'Outra Empresa',
            'nome': 'Outro',
            'email': 'auth@teste.com',
            'senha': 'SenhaForte123!',
        }
        response = api.post('/api/v1/auth/cadastro/', payload)
        assert response.status_code == 400

    def test_empresa_com_nome_repetido_ganha_sufixo(self, api, db):
        # Duas empresas podem ter o mesmo nome; o schema é que precisa ser único.
        from django.db import connection
        connection.set_schema_to_public()
        Tenant.objects.create(schema_name='salao_existente', nome='Salão Existente')
        connection.set_schema_to_public()
        payload = {
            'nome_empresa': 'Salão Existente',
            'nome': 'Ana Silva',
            'email': 'nova@teste.com',
            'senha': 'SenhaForte123!',
        }
        response = api.post('/api/v1/auth/cadastro/', payload)
        assert response.status_code == 201
        assert response.data['schema_name'] == 'salao_existente_2'
        assert response.data['empresa'] == 'Salão Existente'

    def test_senha_fraca_retorna_400(self, api, db):
        payload = {
            'nome_empresa': 'Salão Fraco',
            'nome': 'Ana',
            'email': 'fraco@teste.com',
            'senha': '123',
        }
        response = api.post('/api/v1/auth/cadastro/', payload)
        assert response.status_code == 400

    def test_email_invalido_retorna_400(self, api, db):
        payload = {
            'nome_empresa': 'Salão Inv',
            'nome': 'Ana',
            'email': 'nao-e-email',
            'senha': 'SenhaForte123!',
        }
        response = api.post('/api/v1/auth/cadastro/', payload)
        assert response.status_code == 400

    def test_cria_assinatura_trial_quando_plano_pro_existe(self, api, db):
        from django.db import connection
        from apps_work.billing.models import Assinatura, Plano

        connection.set_schema_to_public()
        # patch_tenant_middleware (via a fixture `api`) já cria uma Assinatura pro
        # tenant de teste 'test_empresa' presa ao Plano 'pro' (PROTECT) — precisa
        # ser removida antes de recriar o Plano do zero.
        Assinatura.objects.filter(plano__nome='pro').delete()
        Plano.objects.filter(nome='pro').delete()
        Plano.objects.create(nome='pro', preco_mensal='69.90')

        payload = {
            'nome_empresa': 'Salão Trial',
            'nome': 'Bia Silva',
            'email': 'bia@teste.com',
            'senha': 'SenhaForte123!',
        }
        response = api.post('/api/v1/auth/cadastro/', payload)
        assert response.status_code == 201

        connection.set_schema_to_public()
        assinatura = Assinatura.objects.get(tenant__schema_name=response.data['schema_name'])
        assert assinatura.status == 'trial'
        assert assinatura.trial_fim == date.today() + timedelta(days=28)
        assert assinatura.plano.nome == 'pro'

    def test_cadastro_funciona_sem_plano_pro_configurado(self, api, db):
        from django.db import connection
        from apps_work.billing.models import Assinatura, Plano

        connection.set_schema_to_public()
        # Idem: precisa desfazer a Assinatura que patch_tenant_middleware cria
        # pro tenant de teste antes de conseguir apagar o Plano 'pro' (PROTECT).
        Assinatura.objects.filter(plano__nome='pro').delete()
        Plano.objects.filter(nome='pro').delete()

        payload = {
            'nome_empresa': 'Salão Sem Plano',
            'nome': 'Caio Silva',
            'email': 'caio@teste.com',
            'senha': 'SenhaForte123!',
        }
        response = api.post('/api/v1/auth/cadastro/', payload)
        assert response.status_code == 201

        connection.set_schema_to_public()
        assert not Assinatura.objects.filter(tenant__schema_name=response.data['schema_name']).exists()


@pytest.mark.django_db
class TestLogin:
    def test_retorna_tokens_e_dados_do_tenant(self, api, user_com_tenant):
        user, tenant = user_com_tenant
        response = api.post('/api/v1/auth/login/', {'email': 'login@teste.com', 'senha': 'SenhaForte123!'})
        assert response.status_code == 200
        assert 'access' in response.data
        assert 'refresh' not in response.data
        assert response.data['schema_name'] == tenant.schema_name
        assert response.data['empresa'] == tenant.nome
        assert response.cookies.get('refresh_token') is not None

    def test_mobile_recebe_refresh_no_corpo_e_sem_cookie(self, api, user_com_tenant):
        response = api.post(
            '/api/v1/auth/login/',
            {'email': 'login@teste.com', 'senha': 'SenhaForte123!'},
            HTTP_X_CLIENT_PLATFORM='mobile',
        )
        assert response.status_code == 200
        assert 'refresh' in response.data
        assert response.cookies.get('refresh_token') is None

    def test_credenciais_invalidas_retorna_401(self, api, user_com_tenant):
        response = api.post('/api/v1/auth/login/', {'email': 'login@teste.com', 'senha': 'errada'})
        assert response.status_code == 401

    def test_usuario_sem_tenant_retorna_400(self, api, user_auth):
        response = api.post('/api/v1/auth/login/', {'email': 'auth@teste.com', 'senha': 'SenhaForte123!'})
        assert response.status_code == 400

    def test_usuario_inativo_com_credenciais_corretas_retorna_403(self, api, user_com_tenant):
        user, _ = user_com_tenant
        user.is_active = False
        user.save()
        response = api.post('/api/v1/auth/login/', {'email': 'login@teste.com', 'senha': 'SenhaForte123!'})
        assert response.status_code == 403
        assert response.data['code'] == 'user_inactive'

    def test_usuario_inativo_com_senha_errada_retorna_401(self, api, user_com_tenant):
        user, _ = user_com_tenant
        user.is_active = False
        user.save()
        response = api.post('/api/v1/auth/login/', {'email': 'login@teste.com', 'senha': 'senhaerrada'})
        assert response.status_code == 401

    def test_email_inexistente_retorna_401(self, api, db):
        response = api.post('/api/v1/auth/login/', {'email': 'naoexiste@email.com', 'senha': 'SenhaForte123!'})
        assert response.status_code == 401


@pytest.mark.django_db
class TestRecuperarSenha:
    def test_email_existente_cria_codigo_e_envia_email(self, api, user_auth):
        with patch('core.email.send_mail') as mock_mail:
            response = api.post('/api/v1/auth/recuperar-senha/', {'email': 'auth@teste.com'})
        assert response.status_code == 200
        assert CodigoRecuperacao.objects.filter(user=user_auth, usado=False).exists()
        mock_mail.assert_called_once()

    def test_email_inexistente_retorna_200_sem_enumerar(self, api, db):
        response = api.post('/api/v1/auth/recuperar-senha/', {'email': 'naoexiste@teste.com'})
        assert response.status_code == 200
        assert 'cadastrado' in response.data['detail']

    def test_novo_codigo_invalida_codigos_anteriores(self, api, user_auth, codigo_recuperacao):
        with patch('core.email.send_mail'):
            api.post('/api/v1/auth/recuperar-senha/', {'email': 'auth@teste.com'})
        codigo_recuperacao.refresh_from_db()
        assert codigo_recuperacao.usado is True


@pytest.mark.django_db
class TestVerificarCodigo:
    def test_codigo_valido_retorna_200(self, api, user_auth, codigo_recuperacao):
        response = api.post('/api/v1/auth/verificar-codigo/', {'email': 'auth@teste.com', 'codigo': '12345678'})
        assert response.status_code == 200

    def test_codigo_invalido_retorna_400(self, api, user_auth):
        response = api.post('/api/v1/auth/verificar-codigo/', {'email': 'auth@teste.com', 'codigo': '00000000'})
        assert response.status_code == 400

    def test_codigo_expirado_retorna_400(self, api, user_auth):
        codigo = CodigoRecuperacao.emitir(user_auth, '99999999')[0]
        codigo.expira_em = timezone.now() - timedelta(minutes=1)
        codigo.save()
        response = api.post('/api/v1/auth/verificar-codigo/', {'email': 'auth@teste.com', 'codigo': '99999999'})
        assert response.status_code == 400

    def test_email_inexistente_retorna_400(self, api, db):
        response = api.post('/api/v1/auth/verificar-codigo/', {'email': 'nao@existe.com', 'codigo': '1234'})
        assert response.status_code == 400


@pytest.mark.django_db
class TestNovaSenha:
    def test_redefine_senha_e_marca_codigo_como_usado(self, api, user_auth, codigo_recuperacao):
        response = api.post('/api/v1/auth/nova-senha/', {
            'email': 'auth@teste.com',
            'codigo': '12345678',
            'nova_senha': 'NovaSenha456!',
        })
        assert response.status_code == 200
        user_auth.refresh_from_db()
        assert user_auth.check_password('NovaSenha456!')
        codigo_recuperacao.refresh_from_db()
        assert codigo_recuperacao.usado is True

    def test_senha_curta_retorna_400(self, api, user_auth, codigo_recuperacao):
        response = api.post('/api/v1/auth/nova-senha/', {
            'email': 'auth@teste.com',
            'codigo': '12345678',
            'nova_senha': '123',
        })
        assert response.status_code == 400

    def test_senha_numerica_simples_retorna_400(self, api, user_auth, codigo_recuperacao):
        response = api.post('/api/v1/auth/nova-senha/', {
            'email': 'auth@teste.com',
            'codigo': '12345678',
            'nova_senha': '12345678',
        })
        assert response.status_code == 400

    def test_codigo_invalido_retorna_400(self, api, user_auth):
        response = api.post('/api/v1/auth/nova-senha/', {
            'email': 'auth@teste.com',
            'codigo': '00000000',
            'nova_senha': 'NovaSenha456!',
        })
        assert response.status_code == 400

    def test_codigo_ja_usado_retorna_400(self, api, user_auth):
        usado, _ = CodigoRecuperacao.emitir(user_auth, '56789012')
        usado.usado = True
        usado.save()
        response = api.post('/api/v1/auth/nova-senha/', {
            'email': 'auth@teste.com',
            'codigo': '56789012',
            'nova_senha': 'NovaSenha456!',
        })
        assert response.status_code == 400

    def test_codigo_expirado_retorna_400(self, api, user_auth):
        codigo = CodigoRecuperacao.emitir(user_auth, '43219876')[0]
        codigo.expira_em = timezone.now() - timedelta(minutes=1)
        codigo.save()
        response = api.post('/api/v1/auth/nova-senha/', {
            'email': 'auth@teste.com',
            'codigo': '43219876',
            'nova_senha': 'NovaSenha456!',
        })
        assert response.status_code == 400

    def test_email_inexistente_retorna_400(self, api, db):
        response = api.post('/api/v1/auth/nova-senha/', {
            'email': 'naoexiste@email.com',
            'codigo': '1234',
            'nova_senha': 'NovaSenha456!',
        })
        assert response.status_code == 400


@pytest.mark.django_db
class TestInatividade:
    def test_sessao_expira_por_inatividade(self, patch_tenant_middleware, usuario):
        from datetime import timedelta
        from django.utils import timezone
        from rest_framework_simplejwt.tokens import AccessToken
        from apps_work.autenticacao.models import UltimaAtividade

        UltimaAtividade.objects.create(
            user=usuario,
            ultimo_acesso=timezone.now() - timedelta(minutes=31),
        )
        token = str(AccessToken.for_user(usuario))
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

        response = client.get('/api/v1/servicos/')
        assert response.status_code == 401
        assert response.json()['code'] == 'inactivity_timeout'

    def test_sessao_ativa_atualiza_ultimo_acesso(self, patch_tenant_middleware, usuario):
        from datetime import timedelta
        from django.utils import timezone
        from rest_framework_simplejwt.tokens import AccessToken
        from apps_work.autenticacao.models import UltimaAtividade

        antes = timezone.now() - timedelta(minutes=5)
        last = UltimaAtividade.objects.create(user=usuario, ultimo_acesso=antes)

        token = str(AccessToken.for_user(usuario))
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

        client.get('/api/v1/servicos/')

        last.refresh_from_db()
        assert last.ultimo_acesso > antes

    def test_login_reseta_ultimo_acesso(self, api, user_com_tenant):
        from datetime import timedelta
        from django.utils import timezone
        from apps_work.autenticacao.models import UltimaAtividade

        user, _ = user_com_tenant
        UltimaAtividade.objects.create(
            user=user,
            ultimo_acesso=timezone.now() - timedelta(hours=2),
        )

        api.post('/api/v1/auth/login/', {'email': 'login@teste.com', 'senha': 'SenhaForte123!'})

        last = UltimaAtividade.objects.get(user=user)
        assert (timezone.now() - last.ultimo_acesso).seconds < 5


def _sessao(user, tenant):
    from apps_work.autenticacao.services import SessaoService
    return SessaoService().emitir(user, tenant)


@pytest.mark.django_db
class TestCookieTokenRefresh:
    def test_refresh_sem_cookie_retorna_401(self, api):
        response = api.post('/api/v1/auth/token-refresh/')
        assert response.status_code == 401

    def test_refresh_com_cookie_valido_retorna_200_e_novo_cookie(self, api, proprietario, tenant):
        refresh = _sessao(proprietario, tenant)
        api.cookies['refresh_token'] = str(refresh)
        response = api.post('/api/v1/auth/token-refresh/')
        assert response.status_code == 200
        assert 'access' in response.data
        assert 'refresh' not in response.data
        novo = response.cookies.get('refresh_token').value
        assert novo and novo != str(refresh)

    def test_refresh_com_cookie_invalido_retorna_401(self, api):
        api.cookies['refresh_token'] = 'token_invalido_qualquer'
        response = api.post('/api/v1/auth/token-refresh/')
        assert response.status_code == 401

    def test_mobile_renova_via_body(self, api, proprietario, tenant):
        # Cliente mobile não gerencia cookies como um navegador — se identifica
        # pelo cabeçalho e manda o refresh no corpo.
        refresh = _sessao(proprietario, tenant)
        response = api.post(
            '/api/v1/auth/token-refresh/', {'refresh': str(refresh)}, HTTP_X_CLIENT_PLATFORM='mobile',
        )
        assert response.status_code == 200
        assert 'access' in response.data
        assert 'refresh' in response.data

    def test_web_nao_renova_via_body(self, api, proprietario, tenant):
        """Sem o cabeçalho de mobile, o refresh só é lido do cookie."""
        refresh = _sessao(proprietario, tenant)
        response = api.post('/api/v1/auth/token-refresh/', {'refresh': str(refresh)})
        assert response.status_code == 401


@pytest.mark.django_db
class TestLogout:
    def test_logout_deleta_cookie(self, api):
        response = api.post('/api/v1/auth/logout/')
        assert response.status_code == 200
        assert 'refresh_token' in response.cookies


@pytest.mark.django_db
class TestCodigoRecuperacaoModel:
    def test_expira_em_definido_automaticamente(self, user_auth):
        antes = timezone.now()
        codigo = CodigoRecuperacao.emitir(user_auth, '11112222')[0]
        assert codigo.expira_em >= antes + timedelta(minutes=14)
        assert codigo.expira_em <= antes + timedelta(minutes=16)

    def test_expirado_false_quando_valido(self, user_auth):
        codigo = CodigoRecuperacao.emitir(user_auth, '22223333')[0]
        assert codigo.expirado is False

    def test_expirado_true_quando_expirado(self, user_auth):
        codigo = CodigoRecuperacao.emitir(user_auth, '33334444')[0]
        codigo.expira_em = timezone.now() - timedelta(minutes=1)
        codigo.save()
        assert codigo.expirado is True

    def test_str_codigo_recuperacao(self, user_auth, codigo_recuperacao):
        assert str(codigo_recuperacao).startswith(f'{user_auth.email} — ')
        assert '12345678' not in str(codigo_recuperacao)


@pytest.mark.django_db
class TestLastActivityModel:
    def test_str_ultima_atividade(self, user_auth):
        from apps_work.autenticacao.models import UltimaAtividade
        activity = UltimaAtividade.objects.create(user=user_auth, ultimo_acesso=timezone.now())
        assert user_auth.email in str(activity)


BEARER_INVALIDO = 'Bearer eyJ.token.expirado-ou-invalido'


@pytest.mark.django_db
class TestEndpointsPublicosIgnoramAuthorizationHeader:
    """Endpoint público não pode virar 401 só porque o cliente mandou um
    Authorization header com token velho/inválido — a autenticação nem deve
    rodar nessas rotas."""

    def test_cadastro_com_bearer_invalido_no_header_ainda_cria_conta(self, api):
        api.credentials(HTTP_AUTHORIZATION=BEARER_INVALIDO)
        response = api.post('/api/v1/auth/cadastro/', {
            'nome_empresa': 'Salão Header',
            'nome': 'Ana Silva',
            'email': 'header@teste.com',
            'senha': 'SenhaForte123!',
        })
        assert response.status_code == 201

    def test_login_com_bearer_invalido_no_header_ainda_autentica(self, api, user_com_tenant):
        api.credentials(HTTP_AUTHORIZATION=BEARER_INVALIDO)
        response = api.post('/api/v1/auth/login/', {'email': 'login@teste.com', 'senha': 'SenhaForte123!'})
        assert response.status_code == 200

    def test_token_refresh_com_bearer_invalido_no_header_ainda_renova(self, api, proprietario, tenant):
        refresh = _sessao(proprietario, tenant)
        api.credentials(HTTP_AUTHORIZATION=BEARER_INVALIDO)
        api.cookies['refresh_token'] = str(refresh)
        response = api.post('/api/v1/auth/token-refresh/')
        assert response.status_code == 200

    def test_recuperar_senha_com_bearer_invalido_no_header_responde_200(self, api, db):
        api.credentials(HTTP_AUTHORIZATION=BEARER_INVALIDO)
        response = api.post('/api/v1/auth/recuperar-senha/', {'email': 'naoexiste@teste.com'})
        assert response.status_code == 200

    def test_logout_com_bearer_invalido_no_header_responde_200(self, api):
        api.credentials(HTTP_AUTHORIZATION=BEARER_INVALIDO)
        response = api.post('/api/v1/auth/logout/')
        assert response.status_code == 200
