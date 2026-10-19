import pytest
from rest_framework.test import APIClient

from apps_work.notificacoes.models import Notificacao


@pytest.fixture
def client_autenticado(patch_tenant_middleware, usuario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=usuario)
    return client


@pytest.fixture
def notificacao_nao_lida(patch_tenant_middleware):
    return Notificacao.objects.create(tipo='cliente_vinculado', titulo='Ana agora é seu cliente')


@pytest.fixture
def notificacao_lida(patch_tenant_middleware):
    return Notificacao.objects.create(tipo='cliente_desvinculado', titulo='Pedro não é mais seu cliente', lida=True)


@pytest.mark.django_db
class TestNotificacaoAPI:
    def test_listar_retorna_200_paginado(self, client_autenticado, notificacao_nao_lida, notificacao_lida):
        response = client_autenticado.get('/api/notificacoes/')
        assert response.status_code == 200
        assert 'results' in response.data
        assert response.data['count'] == 2

    def test_listar_ordena_mais_recente_primeiro(self, client_autenticado, notificacao_nao_lida, notificacao_lida):
        response = client_autenticado.get('/api/notificacoes/')
        titulos = [n['titulo'] for n in response.data['results']]
        assert titulos[0] == notificacao_lida.titulo  # criada por último

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/notificacoes/')
        assert response.status_code == 401

    def test_nao_lidas_conta_corretamente(self, client_autenticado, notificacao_nao_lida, notificacao_lida):
        response = client_autenticado.get('/api/notificacoes/nao-lidas/')
        assert response.status_code == 200
        assert response.data['total'] == 1

    def test_marcar_lida_atualiza_notificacao(self, client_autenticado, notificacao_nao_lida):
        response = client_autenticado.post(f'/api/notificacoes/{notificacao_nao_lida.id}/marcar-lida/')
        assert response.status_code == 200
        notificacao_nao_lida.refresh_from_db()
        assert notificacao_nao_lida.lida is True

    def test_marcar_todas_lidas_zera_contagem(self, client_autenticado, notificacao_nao_lida):
        Notificacao.objects.create(tipo='cliente_vinculado', titulo='Outra')
        response = client_autenticado.post('/api/notificacoes/marcar-todas-lidas/')
        assert response.status_code == 200

        contagem = client_autenticado.get('/api/notificacoes/nao-lidas/')
        assert contagem.data['total'] == 0
