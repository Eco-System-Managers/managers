"""Ordem dos middlewares e configurações de HTTPS (issue #13)."""
import os
import secrets
import subprocess
import sys
from datetime import timedelta
from pathlib import Path

import pytest
from django.conf import settings
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps_work.autenticacao.models import UltimaAtividade

ORIGEM = settings.CORS_ALLOWED_ORIGINS[0]


def test_security_e_cors_vem_antes_de_quem_responde_sozinho():
    ordem = settings.MIDDLEWARE
    cors = ordem.index('corsheaders.middleware.CorsMiddleware')
    assert ordem.index('django.middleware.security.SecurityMiddleware') < cors
    for middleware in (
        'django_tenants.middleware.main.TenantMainMiddleware',
        'core.middleware.JWTTenantMiddleware',
        'core.middleware.AssinaturaBloqueadaMiddleware',
        'core.middleware.InactivityMiddleware',
    ):
        assert cors < ordem.index(middleware)


@pytest.fixture
def tenant_bloqueado(tenant):
    """Tenant de teste resolvido pelo domínio de verdade, sem assinatura."""
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    return client


@pytest.mark.django_db
class TestCorsNasRespostasDosMiddlewares:
    def test_402_da_assinatura_sai_com_cors(self, tenant_bloqueado):
        response = tenant_bloqueado.get('/api/v1/servicos/', HTTP_ORIGIN=ORIGEM)
        assert response.status_code == 402
        assert response['Access-Control-Allow-Origin'] == ORIGEM

    def test_preflight_em_tenant_bloqueado_e_respondido_pelo_cors(self, tenant_bloqueado):
        response = tenant_bloqueado.options(
            '/api/v1/servicos/',
            HTTP_ORIGIN=ORIGEM,
            HTTP_ACCESS_CONTROL_REQUEST_METHOD='GET',
        )
        assert response.status_code == 200
        assert response['Access-Control-Allow-Origin'] == ORIGEM

    def test_401_de_inatividade_sai_com_cors(self, patch_tenant_middleware, proprietario, tenant):
        UltimaAtividade.objects.create(user=proprietario, ultimo_acesso=timezone.now() - timedelta(hours=2))
        refresh = RefreshToken.for_user(proprietario)
        refresh['schema_name'] = tenant.schema_name

        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        response = client.get('/api/v1/servicos/', HTTP_ORIGIN=ORIGEM)

        assert response.status_code == 401
        assert response.json()['code'] == 'inactivity_timeout'
        assert response['Access-Control-Allow-Origin'] == ORIGEM


def test_https_desligado_por_padrao():
    # Ligado aqui, toda requisição dos testes viraria 301.
    assert settings.HTTPS is False
    assert not getattr(settings, 'SECURE_SSL_REDIRECT', False)


def _check_deploy(**ambiente):
    env = {**os.environ, 'DJANGO_SETTINGS_MODULE': 'core.settings', **ambiente}
    return subprocess.run(
        [sys.executable, 'manage.py', 'check', '--deploy'],
        cwd=Path(__file__).resolve().parent.parent,
        env=env,
        capture_output=True,
        text=True,
    )


def test_check_deploy_sem_avisos_com_https():
    resultado = _check_deploy(
        HTTPS='True', DEBUG='False', SECRET_KEY=secrets.token_urlsafe(60),
    )
    assert resultado.returncode == 0, resultado.stderr
    assert 'no issues' in resultado.stdout, resultado.stdout + resultado.stderr


def test_header_de_proxy_so_com_proxy():
    chave = secrets.token_urlsafe(60)
    codigo = 'from django.conf import settings; print(getattr(settings, "SECURE_PROXY_SSL_HEADER", None))'
    base = {**os.environ, 'DJANGO_SETTINGS_MODULE': 'core.settings', 'HTTPS': 'True', 'SECRET_KEY': chave}

    def ler(num_proxies):
        r = subprocess.run(
            [sys.executable, '-c', f'import django; django.setup(); {codigo}'],
            cwd=Path(__file__).resolve().parent.parent,
            env={**base, 'NUM_PROXIES': num_proxies},
            capture_output=True, text=True,
        )
        return r.stdout.strip()

    assert ler('0') == 'None'
    assert 'HTTP_X_FORWARDED_PROTO' in ler('1')
