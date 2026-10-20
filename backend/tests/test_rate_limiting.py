"""Rate limiting por IP, por conta e por produto (issue #12)."""
from types import SimpleNamespace
from unittest.mock import patch

import pytest
from django.contrib.auth.models import User
from django.db import connection
from django.test import override_settings
from django_tenants.middleware.main import TenantMainMiddleware
from rest_framework.settings import api_settings
from rest_framework.test import APIClient

from apps_serv.consumidores.models import Consumidor
from apps_serv.consumidores.services import RegistroConsumidorService
from core.limites import LimiteDeFalhas, MuitasTentativas
from core.throttling import UsuarioRateThrottle

LOGIN_B2B = '/auth/login/'
LOGIN_B2C = '/api/sm/auth/login/'


@pytest.fixture
def api(patch_tenant_middleware):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    return client


@pytest.fixture
def api_sm(db):
    def _publico(_self, request):
        connection.set_schema_to_public()

    with override_settings(ALLOWED_HOSTS=['*']):
        with patch.object(TenantMainMiddleware, 'process_request', _publico):
            yield APIClient()


def _login(client, url, email, senha='errada', **extra):
    return client.post(url, {'email': email, 'senha': senha}, **extra)


# ---------------------------------------------------------------------------
# Identidade do cliente
# ---------------------------------------------------------------------------

def test_num_proxies_padrao_e_zero():
    assert api_settings.NUM_PROXIES == 0


@pytest.mark.django_db
def test_x_forwarded_for_nao_burla_o_limite_por_ip(api):
    rate = int(api_settings.DEFAULT_THROTTLE_RATES['auth_login'].split('/')[0])
    for i in range(rate):
        _login(api, LOGIN_B2B, f'u{i}@x.com', HTTP_X_FORWARDED_FOR=f'10.0.0.{i}')

    response = _login(api, LOGIN_B2B, 'outro@x.com', HTTP_X_FORWARDED_FOR='10.9.9.9')
    assert response.status_code == 429


# ---------------------------------------------------------------------------
# Escopos por produto
# ---------------------------------------------------------------------------

@pytest.mark.django_db
def test_login_do_b2b_nao_gasta_o_limite_do_b2c(api, api_sm):
    rate = int(api_settings.DEFAULT_THROTTLE_RATES['auth_login'].split('/')[0])
    for i in range(rate):
        _login(api, LOGIN_B2B, f'u{i}@x.com')
    assert _login(api, LOGIN_B2B, 'mais@x.com').status_code == 429

    assert _login(api_sm, LOGIN_B2C, 'cliente@x.com').status_code == 401


def test_chave_de_usuario_inclui_o_produto():
    throttle = UsuarioRateThrottle()
    user = User(pk=5)
    consumidor = Consumidor(pk=5)

    chave_user = throttle.get_cache_key(SimpleNamespace(user=user), None)
    chave_consumidor = throttle.get_cache_key(SimpleNamespace(user=consumidor), None)

    assert chave_user != chave_consumidor


def test_usuario_anonimo_fica_com_o_throttle_de_anonimo():
    anonimo = SimpleNamespace(is_authenticated=False)
    assert UsuarioRateThrottle().get_cache_key(SimpleNamespace(user=anonimo), None) is None


# ---------------------------------------------------------------------------
# Falhas de login por conta
# ---------------------------------------------------------------------------

class TestLimiteDeFalhas:
    def test_bloqueia_ao_atingir_o_maximo(self):
        limite = LimiteDeFalhas('teste', maximo=3)
        for _ in range(3):
            limite.registrar_falha('a@x.com')
        with pytest.raises(MuitasTentativas):
            limite.verificar('a@x.com')

    def test_acerto_zera_a_contagem(self):
        limite = LimiteDeFalhas('teste', maximo=3)
        for _ in range(2):
            limite.registrar_falha('a@x.com')
        limite.limpar('a@x.com')
        limite.registrar_falha('a@x.com')
        limite.verificar('a@x.com')

    def test_email_normalizado(self):
        limite = LimiteDeFalhas('teste', maximo=1)
        limite.registrar_falha('  A@X.com ')
        with pytest.raises(MuitasTentativas):
            limite.verificar('a@x.com')


@pytest.mark.django_db
class TestFalhasDeLoginB2B:
    @pytest.fixture(autouse=True)
    def sem_throttle_por_ip(self):
        # Isola o contador de falhas do throttle por IP de 5/min.
        with patch('rest_framework.throttling.ScopedRateThrottle.allow_request', return_value=True):
            yield

    def test_bloqueia_a_conta_depois_de_10_falhas(self, api, proprietario):
        for _ in range(10):
            assert _login(api, LOGIN_B2B, proprietario.username).status_code == 401

        # Nem a senha certa entra enquanto a janela não passa.
        response = _login(api, LOGIN_B2B, proprietario.username, senha='senha123')
        assert response.status_code == 429
        assert response.data['code'] == 'muitas_tentativas'

    def test_acerto_zera_as_falhas(self, api, proprietario):
        for _ in range(9):
            _login(api, LOGIN_B2B, proprietario.username)
        assert _login(api, LOGIN_B2B, proprietario.username, senha='senha123').status_code == 200
        for _ in range(9):
            _login(api, LOGIN_B2B, proprietario.username)
        assert _login(api, LOGIN_B2B, proprietario.username, senha='senha123').status_code == 200

    def test_bloqueio_vale_para_email_inexistente(self, api):
        # Bloquear só quem tem conta revelaria quem tem conta.
        for _ in range(10):
            _login(api, LOGIN_B2B, 'ninguem@x.com')
        assert _login(api, LOGIN_B2B, 'ninguem@x.com').status_code == 429

    def test_bloqueio_de_uma_conta_nao_afeta_outra(self, api, proprietario):
        for _ in range(10):
            _login(api, LOGIN_B2B, 'atacada@x.com')
        assert _login(api, LOGIN_B2B, proprietario.username, senha='senha123').status_code == 200


@pytest.mark.django_db
class TestFalhasDeLoginB2C:
    @pytest.fixture(autouse=True)
    def sem_throttle_por_ip(self):
        with patch('rest_framework.throttling.ScopedRateThrottle.allow_request', return_value=True):
            yield

    def test_bloqueia_a_conta_depois_de_10_falhas(self, api_sm):
        RegistroConsumidorService().registrar(
            nome='Carla', email='carla@sm.com', senha='SenhaForte123!', telefone='11999990000',
        )
        for _ in range(10):
            assert _login(api_sm, LOGIN_B2C, 'carla@sm.com').status_code == 401

        response = _login(api_sm, LOGIN_B2C, 'carla@sm.com', senha='SenhaForte123!')
        assert response.status_code == 429


# ---------------------------------------------------------------------------
# Recuperação por conta
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestRecuperacaoPorEmail:
    @pytest.fixture(autouse=True)
    def sem_throttle_por_ip(self):
        # Desliga só o limite por IP (ScopedRateThrottle); o por e-mail segue ativo.
        with patch('rest_framework.throttling.ScopedRateThrottle.allow_request', return_value=True):
            yield

    def test_b2b_limita_codigos_por_email_de_ips_diferentes(self, api):
        for i in range(5):
            response = api.post('/auth/recuperar-senha/', {'email': 'alvo@x.com'}, REMOTE_ADDR=f'10.0.0.{i}')
            assert response.status_code == 200

        response = api.post('/auth/recuperar-senha/', {'email': 'alvo@x.com'}, REMOTE_ADDR='10.0.0.99')
        assert response.status_code == 429
        assert api.post('/auth/recuperar-senha/', {'email': 'outro@x.com'}).status_code == 200

    def test_b2c_limita_codigos_por_email(self, api_sm):
        for _ in range(5):
            api_sm.post('/api/sm/auth/recuperar-senha/', {'email': 'alvo@x.com'})
        response = api_sm.post('/api/sm/auth/recuperar-senha/', {'email': 'alvo@x.com'})
        assert response.status_code == 429


# ---------------------------------------------------------------------------
# Throttles padrão
# ---------------------------------------------------------------------------

def test_throttles_padrao_configurados():
    # É o que as views herdam (lido na importação), não o api_settings atual.
    from rest_framework.views import APIView
    padrao = APIView.throttle_classes
    assert any(c.__name__ == 'AnonRateThrottle' for c in padrao)
    assert any(c.__name__ == 'UsuarioRateThrottle' for c in padrao)


@pytest.mark.django_db
def test_rota_publica_sem_escopo_tem_limite_de_anonimo(api_sm):
    # O refresh do B2C não declara throttle próprio: fica com o de anônimo.
    with patch('rest_framework.throttling.AnonRateThrottle.get_rate', return_value='2/min'):
        for _ in range(2):
            assert api_sm.post('/api/sm/auth/refresh/').status_code == 401
        assert api_sm.post('/api/sm/auth/refresh/').status_code == 429
