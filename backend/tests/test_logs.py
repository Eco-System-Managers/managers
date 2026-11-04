"""A linha de log de cada requisição da API (core/requisicao.py, core/logs.py)."""
import json
import logging

import pytest
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import AccessToken

from core.logs import FormatoJson


class _Coletor(logging.Handler):
    def __init__(self):
        super().__init__()
        self.registros = []

    def emit(self, record):
        self.registros.append(record)


@pytest.fixture
def linhas():
    """Os registros do logger das requisições. O caplog não serve: o logger
    não propaga para o root, onde o caplog escuta."""
    logger = logging.getLogger('workmanage.requisicao')
    coletor = _Coletor()
    nivel = logger.level
    logger.addHandler(coletor)
    logger.setLevel(logging.INFO)
    yield coletor.registros
    logger.removeHandler(coletor)
    logger.setLevel(nivel)


@pytest.fixture
def client(patch_tenant_middleware):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    return client


def test_formato_json_numa_linha_com_traceback():
    try:
        raise RuntimeError('quebrou')
    except RuntimeError:
        import sys
        registro = logging.LogRecord('x', logging.ERROR, __file__, 1, 'falhou %s', ('aqui',), sys.exc_info())
    registro.dados = {'status': 500}

    saida = FormatoJson().format(registro)

    assert '\n' not in saida
    linha = json.loads(saida)
    assert linha['level'] == 'error'
    assert linha['message'] == 'falhou aqui'
    assert linha['status'] == 500
    assert 'RuntimeError: quebrou' in linha['traceback']


def test_aviso_sai_como_warn():
    registro = logging.LogRecord('x', logging.WARNING, __file__, 1, 'cuidado', (), None)
    assert json.loads(FormatoJson().format(registro))['level'] == 'warn'


@pytest.mark.django_db
def test_requisicao_autenticada_sai_com_quem_e_sem_a_query(client, proprietario, tenant, linhas):
    token = AccessToken.for_user(proprietario)
    token['schema_name'] = tenant.schema_name
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}', HTTP_X_CLIENT_PLATFORM='mobile')

    response = client.get('/api/v1/clientes/?search=Maria')

    assert response.status_code == 200
    [registro] = linhas
    assert registro.levelno == logging.INFO
    assert registro.getMessage().startswith('GET /api/v1/clientes/ 200 ')
    dados = registro.dados
    assert dados['rota'] == 'cliente-list'
    assert dados['user_id'] == proprietario.pk
    assert dados['papel'] == 'proprietario'
    assert dados['schema_name'] == tenant.schema_name
    assert dados['plataforma'] == 'mobile'
    assert 'Maria' not in json.dumps(dados)


@pytest.mark.django_db
def test_erro_sai_como_aviso_com_o_code(client, proprietario, linhas):
    client.force_authenticate(user=proprietario)

    response = client.post('/api/v1/clientes/', {}, format='json')

    assert response.status_code == 400
    [registro] = linhas
    assert registro.levelno == logging.WARNING
    assert registro.dados['codigo'] == 'invalido'
    assert registro.dados['user_id'] == proprietario.pk


@pytest.mark.django_db
def test_sem_login_sai_sem_usuario(client, linhas):
    response = client.get('/api/v1/clientes/')

    assert response.status_code == 401
    [registro] = linhas
    assert registro.dados['user_id'] is None
    assert registro.dados['codigo'] == 'nao_autenticado'


@pytest.mark.django_db
def test_token_do_link_nao_vai_para_o_log(client, linhas):
    client.get('/api/v1/convites/info/abc123segredo/')

    [registro] = linhas
    assert 'abc123segredo' not in json.dumps(registro.dados)
    assert registro.dados['caminho'] == '/api/v1/convites/info/:token/'


@pytest.mark.django_db
def test_fora_da_api_nao_loga(client, linhas):
    client.get('/privacidade')
    assert linhas == []


@pytest.mark.django_db
def test_402_do_middleware_sai_com_o_code_e_o_usuario_do_token(tenant, proprietario, linhas):
    """Tenant sem assinatura: o 402 sai antes do DRF, e o usuário vem do token."""
    token = AccessToken.for_user(proprietario)
    token['schema_name'] = tenant.schema_name
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

    response = client.get('/api/v1/clientes/')

    assert response.status_code == 402
    [registro] = linhas
    assert registro.dados['codigo'] == 'assinatura_bloqueada'
    assert registro.dados['user_id'] == proprietario.pk
    assert registro.dados['schema_name'] == tenant.schema_name
