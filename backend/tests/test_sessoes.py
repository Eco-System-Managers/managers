"""Sessões revogáveis e chaves de assinatura (issue #10)."""
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone as dt_timezone
from pathlib import Path
from unittest.mock import patch

import jwt
import pytest
from django.conf import settings
from django.db import connection
from django.test import override_settings
from django.utils import timezone
from django_tenants.middleware.main import TenantMainMiddleware
from rest_framework.test import APIClient

from apps_serv.autenticacao.authentication import gerar_tokens
from apps_serv.consumidores.models import CodigoRecuperacaoConsumidor, Consumidor
from apps_serv.consumidores.services import RegistroConsumidorService
from apps_work.autenticacao.models import CodigoRecuperacao
from apps_work.autenticacao.services import SessaoService
from apps_work.usuarios.models import Colaborador
from apps_work.usuarios.services import ColaboradorService
from tenants.models import Membro

MOBILE = {'HTTP_X_CLIENT_PLATFORM': 'mobile'}


# ---------------------------------------------------------------------------
# Work Manage (B2B)
# ---------------------------------------------------------------------------

@pytest.fixture
def api(patch_tenant_middleware):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    return client


@pytest.fixture
def sessao(proprietario, tenant):
    return SessaoService().emitir(proprietario, tenant)


def _renovar(api, refresh):
    return api.post('/api/v1/auth/token-refresh/', {'refresh': str(refresh)}, **MOBILE)


def _acessar(api, access):
    api.credentials(HTTP_AUTHORIZATION=f'Bearer {access}')
    return api.get('/api/v1/colaboradores/')


@pytest.mark.django_db
class TestRotacaoB2B:
    def test_refresh_usado_nao_vale_de_novo(self, api, sessao):
        assert _renovar(api, sessao).status_code == 200
        assert _renovar(api, sessao).status_code == 401

    def test_refresh_novo_continua_a_sessao(self, api, sessao):
        novo = _renovar(api, sessao).data['refresh']
        assert _renovar(api, novo).status_code == 200

    def test_access_renovado_acessa_a_api(self, api, sessao):
        access = _renovar(api, sessao).data['access']
        assert _acessar(api, access).status_code == 200


@pytest.mark.django_db
class TestRevogacaoB2B:
    def test_logout_revoga_o_refresh(self, api, sessao):
        assert api.post('/api/v1/auth/logout/', {'refresh': str(sessao)}, **MOBILE).status_code == 200
        assert _renovar(api, sessao).status_code == 401

    def test_logout_web_revoga_o_refresh_do_cookie(self, api, sessao):
        api.cookies['refresh_token'] = str(sessao)
        api.post('/api/v1/auth/logout/')
        assert _renovar(api, sessao).status_code == 401

    def test_logout_com_refresh_invalido_responde_200(self, api):
        response = api.post('/api/v1/auth/logout/', {'refresh': 'lixo'}, **MOBILE)
        assert response.status_code == 200

    def test_troca_de_senha_derruba_refresh_e_access(self, api, sessao, proprietario):
        access = str(sessao.access_token)
        CodigoRecuperacao.emitir(proprietario, '12345678')

        response = api.post('/api/v1/auth/nova-senha/', {
            'email': proprietario.email, 'codigo': '12345678', 'nova_senha': 'OutraSenha456!',
        })

        assert response.status_code == 200
        assert _renovar(api, sessao).status_code == 401
        assert _acessar(api, access).status_code == 401

    def test_desativar_colaborador_derruba_o_refresh(self, api, tenant):
        from django.contrib.auth.models import User
        user = User.objects.create_user(username='c@email.com', email='c@email.com', password='x')
        Membro.objects.create(user=user, tenant=tenant, papel='colaborador')
        colaborador = Colaborador.objects.create(user=user)
        refresh = SessaoService().emitir(user, tenant)

        ColaboradorService().desativar(colaborador)
        ColaboradorService().reativar(colaborador)

        # Reativado, ele entra de novo pelo login — não pela sessão antiga.
        assert _renovar(api, refresh).status_code == 401

    def test_refresh_sem_vinculo_com_o_tenant_e_recusado(self, api, sessao, proprietario):
        Membro.objects.filter(user=proprietario).delete()
        assert _renovar(api, sessao).status_code == 401

    def test_refresh_de_usuario_inativo_e_recusado(self, api, sessao, proprietario):
        proprietario.is_active = False
        proprietario.save()
        assert _renovar(api, sessao).status_code == 401


@pytest.mark.django_db
class TestEndpointDeRefreshDuplicado:
    def test_rota_do_simplejwt_nao_existe_mais(self, api, sessao):
        response = api.post('/api/v1/token/refresh/', {'refresh': str(sessao)})
        assert response.status_code == 404


# ---------------------------------------------------------------------------
# Chaves de assinatura
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestChavesDeAssinatura:
    def test_token_assinado_com_a_secret_key_e_recusado(self, api, proprietario):
        # O formato antigo: assinado direto com a SECRET_KEY, sem aud/iss.
        forjado = jwt.encode(
            {
                'token_type': 'access', 'user_id': str(proprietario.pk), 'jti': 'x',
                'schema_name': 'test_empresa',
                'exp': datetime.now(dt_timezone.utc) + timedelta(minutes=5),
            },
            settings.SECRET_KEY,
            algorithm='HS256',
        )
        assert _acessar(api, forjado).status_code == 401

    def test_produtos_usam_chaves_diferentes(self):
        assert settings.SIMPLE_JWT['SIGNING_KEY'] != settings.SERVICEMANAGE_JWT['SIGNING_KEY']
        assert settings.SIMPLE_JWT['SIGNING_KEY'] != settings.SECRET_KEY

    def test_token_do_b2c_nao_autentica_no_b2b(self, api, consumidor):
        access, _ = gerar_tokens(consumidor)
        assert _acessar(api, access).status_code == 401

    def test_token_do_b2b_nao_autentica_no_b2c(self, api_sm, sessao):
        api_sm.credentials(HTTP_AUTHORIZATION=f'Bearer {sessao.access_token}')
        assert api_sm.get('/api/sm/v1/me/').status_code == 401


def test_aplicacao_nao_sobe_sem_secret_key():
    ambiente = {**os.environ, 'SECRET_KEY': '', 'DJANGO_SETTINGS_MODULE': 'core.settings'}
    resultado = subprocess.run(
        [sys.executable, '-c', 'import django; django.setup()'],
        cwd=Path(__file__).resolve().parent.parent,
        env=ambiente,
        capture_output=True,
        text=True,
    )
    assert resultado.returncode != 0
    assert 'SECRET_KEY' in resultado.stderr


# ---------------------------------------------------------------------------
# Service Manage (B2C)
# ---------------------------------------------------------------------------

@pytest.fixture
def api_sm(db):
    def _publico(_self, request):
        connection.set_schema_to_public()

    with override_settings(ALLOWED_HOSTS=['*']):
        with patch.object(TenantMainMiddleware, 'process_request', _publico):
            yield APIClient()


@pytest.fixture
def consumidor(db):
    return RegistroConsumidorService().registrar(
        nome='Carla', email='carla@sm.com', senha='SenhaForte123!', telefone='11999990000',
    )


def _login_sm(api_sm):
    response = api_sm.post(
        '/api/sm/v1/auth/login/', {'email': 'carla@sm.com', 'senha': 'SenhaForte123!'}, **MOBILE,
    )
    assert response.status_code == 200
    return response.data['access'], response.data['refresh']


def _renovar_sm(api_sm, refresh):
    return api_sm.post('/api/sm/v1/auth/refresh/', {'refresh': refresh}, **MOBILE)


@pytest.mark.django_db
class TestSessoesB2C:
    def test_web_recebe_refresh_so_no_cookie(self, api_sm, consumidor):
        response = api_sm.post('/api/sm/v1/auth/login/', {'email': 'carla@sm.com', 'senha': 'SenhaForte123!'})
        assert 'refresh' not in response.data
        assert response.cookies.get('sm_refresh_token') is not None

    def test_refresh_usado_nao_vale_de_novo(self, api_sm, consumidor):
        _, refresh = _login_sm(api_sm)
        assert _renovar_sm(api_sm, refresh).status_code == 200
        assert _renovar_sm(api_sm, refresh).status_code == 401

    def test_refresh_novo_continua_a_sessao(self, api_sm, consumidor):
        _, refresh = _login_sm(api_sm)
        novo = _renovar_sm(api_sm, refresh).data['refresh']
        assert _renovar_sm(api_sm, novo).status_code == 200

    def test_renovacao_devolve_o_consumidor_como_o_login(self, api_sm, consumidor):
        _, refresh = _login_sm(api_sm)
        response = _renovar_sm(api_sm, refresh)
        assert response.data['consumidor']['id'] == consumidor.id
        assert response.data['consumidor']['email'] == consumidor.email

    def test_logout_revoga_o_refresh(self, api_sm, consumidor):
        _, refresh = _login_sm(api_sm)
        assert api_sm.post('/api/sm/v1/auth/logout/', {'refresh': refresh}, **MOBILE).status_code == 200
        assert _renovar_sm(api_sm, refresh).status_code == 401

    def test_troca_de_senha_derruba_access_e_refresh(self, api_sm, consumidor):
        access, refresh = _login_sm(api_sm)
        CodigoRecuperacaoConsumidor.emitir(consumidor, '12345678')

        # O token tem resolução de segundos; a troca acontece "depois" dele.
        depois = timezone.now() + timedelta(seconds=5)
        with patch('apps_serv.consumidores.services.timezone.now', return_value=depois):
            response = api_sm.post('/api/sm/v1/auth/nova-senha/', {
                'email': 'carla@sm.com', 'codigo': '12345678', 'nova_senha': 'OutraSenha456!',
            })
        assert response.status_code == 200

        assert _renovar_sm(api_sm, refresh).status_code == 401
        api_sm.credentials(HTTP_AUTHORIZATION=f'Bearer {access}')
        assert api_sm.get('/api/sm/v1/me/').status_code == 401

    def test_login_depois_da_troca_de_senha_funciona(self, api_sm, consumidor):
        Consumidor.objects.filter(pk=consumidor.pk).update(
            sessoes_validas_desde=timezone.now() - timedelta(seconds=5),
        )
        access, _ = _login_sm(api_sm)
        api_sm.credentials(HTTP_AUTHORIZATION=f'Bearer {access}')
        assert api_sm.get('/api/sm/v1/me/').status_code == 200

    def test_access_nao_serve_como_refresh(self, api_sm, consumidor):
        access, _ = _login_sm(api_sm)
        assert _renovar_sm(api_sm, access).status_code == 401
