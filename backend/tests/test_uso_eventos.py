"""Os eventos de uso que o RequisicaoMiddleware grava (apps_work/uso/registro.py)."""
from unittest.mock import patch

import pytest
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import AccessToken

from apps_work.empresa.models import EmpresaConfig
from apps_work.uso.models import EventoDeUso
from apps_work.uso.registro import deve_registrar, nome_do_evento


@pytest.mark.parametrize('rota, metodo, esperado', [
    ('agendamento-list', 'POST', 'agendamento.criar'),
    ('agendamento-detail', 'PATCH', 'agendamento.editar'),
    ('agendamento-detail', 'PUT', 'agendamento.editar'),
    ('atendimento-kanban-detail', 'DELETE', 'atendimento-kanban.remover'),
    ('agendamento-detail', 'GET', 'agendamento.ver'),
    ('agendamento-cobrar', 'POST', 'agendamento-cobrar'),
    ('kanban-capacidade', 'PUT', 'kanban-capacidade.put'),
    ('empresa-config', 'PATCH', 'empresa-config.patch'),
    ('colaborador-me', 'GET', 'app.aberto'),
])
def test_nome_do_evento(rota, metodo, esperado):
    assert nome_do_evento(rota, metodo) == esperado


@pytest.mark.parametrize('rota, metodo, status, codigo, esperado', [
    ('agendamento-list', 'POST', 201, '', True),
    ('agendamento-list', 'POST', 400, 'horario_conflito', True),
    ('agendamento-list', 'GET', 200, '', False),
    ('agendamento-list', 'GET', 500, '', True),
    ('colaborador-me', 'GET', 200, '', True),
    ('auth-token-refresh', 'POST', 200, '', False),
    ('cliente-list', 'GET', 401, 'token_invalido', False),
    ('', 'GET', 404, 'nao_encontrado', False),
    ('cliente-list', 'OPTIONS', 200, '', False),
])
def test_o_que_vira_evento(rota, metodo, status, codigo, esperado):
    assert deve_registrar(rota, metodo, status, codigo) is esperado


@pytest.fixture
def client(patch_tenant_middleware, proprietario, tenant):
    EmpresaConfig.objects.create(pk=1, nichos=['cabeleireiro'])
    token = AccessToken.for_user(proprietario)
    token['schema_name'] = tenant.schema_name
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.credentials(
        HTTP_AUTHORIZATION=f'Bearer {token}', HTTP_X_CLIENT_PLATFORM='mobile', HTTP_X_APP_VERSION='1.0.0+1',
    )
    return client


@pytest.mark.django_db
class TestEventosGravados:
    def test_criar_grava_quem_o_que_e_como(self, client, proprietario, tenant):
        response = client.post('/api/v1/servicos/', {'nome': 'Corte', 'duracao': 30, 'preco': '50.00'}, format='json')

        assert response.status_code == 201
        evento = EventoDeUso.objects.get()
        assert evento.evento == 'servico.criar'
        assert evento.metodo == 'POST'
        assert evento.status == 201
        assert evento.schema_name == tenant.schema_name
        assert evento.user_id == proprietario.pk
        assert evento.papel == 'proprietario'
        assert evento.plataforma == 'mobile'
        assert evento.versao_app == '1.0.0+1'
        assert evento.duracao_ms >= 0

    def test_editar_guarda_o_id_do_objeto(self, client):
        servico = client.post('/api/v1/servicos/', {'nome': 'Corte', 'duracao': 30, 'preco': '50.00'}, format='json')
        client.patch(f"/api/v1/servicos/{servico.data['id']}/", {'preco': '60.00'}, format='json')

        evento = EventoDeUso.objects.get(evento='servico.editar')
        assert evento.objeto_id == str(servico.data['id'])

    def test_erro_de_regra_guarda_o_code(self, client):
        client.post('/api/v1/servicos/', {}, format='json')

        evento = EventoDeUso.objects.get()
        assert evento.status == 400
        assert evento.codigo == 'invalido'

    def test_leitura_nao_grava_e_abrir_o_app_grava(self, client):
        client.get('/api/v1/servicos/')
        assert not EventoDeUso.objects.exists()

        client.get('/api/v1/colaboradores/me/')
        assert EventoDeUso.objects.get().evento == 'app.aberto'

    def test_login_grava_quem_entrou(self, patch_tenant_middleware, proprietario, tenant):
        proprietario.set_password('SenhaForte123!')
        proprietario.save()

        response = APIClient().post(
            '/api/v1/auth/login/', {'email': proprietario.email, 'senha': 'SenhaForte123!'}, format='json',
        )

        assert response.status_code == 200
        evento = EventoDeUso.objects.get()
        assert evento.evento == 'auth-login'
        assert evento.user_id == proprietario.pk
        assert evento.schema_name == tenant.schema_name

    def test_falha_ao_gravar_nao_derruba_a_resposta(self, client):
        with patch.object(EventoDeUso.objects, 'create', side_effect=RuntimeError('banco fora')):
            response = client.post('/api/v1/servicos/', {'nome': 'Corte', 'duracao': 30, 'preco': '50.00'}, format='json')

        assert response.status_code == 201

    def test_service_manage_nao_grava(self, db):
        APIClient().post('/api/sm/v1/auth/login/', {'email': 'x@x.com', 'senha': 'errada'}, format='json')
        assert not EventoDeUso.objects.exists()
