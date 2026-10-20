import pytest
from decimal import Decimal
from datetime import timedelta
from unittest.mock import patch

from django.db import connection
from django.utils import timezone
from django_tenants.middleware.main import TenantMainMiddleware
from django.test import override_settings
from django.test.utils import CaptureQueriesContext
from rest_framework.test import APIClient
from apps_serv.autenticacao.authentication import gerar_tokens
from apps_serv.consumidores.models import AgendamentoConsumidor, VinculoConsumidor
from apps_serv.consumidores.services import RegistroConsumidorService
from apps_serv.vitrine.models import NegocioPublico


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def patch_public_middleware():
    """Patches TenantMainMiddleware to keep the connection in the public schema."""
    def _process_request(_self, request):
        connection.set_schema_to_public()

    with override_settings(ALLOWED_HOSTS=['*']):
        with patch.object(TenantMainMiddleware, 'process_request', _process_request):
            yield


@pytest.fixture
def consumidor(db):
    return RegistroConsumidorService().registrar(
        nome='João Consumidor',
        email='joao@sm.com',
        senha='SenhaForte123!',
    )


@pytest.fixture
def api_anonimo(patch_public_middleware):
    return APIClient()


@pytest.fixture
def api_autenticado(patch_public_middleware, consumidor):
    access, _ = gerar_tokens(consumidor)
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {access}')
    return client, consumidor


@pytest.fixture
def agendamento_ativo(consumidor):
    return AgendamentoConsumidor.objects.create(
        consumidor=consumidor,
        schema_name='barbearia_teste',
        agendamento_id=99,
        negocio_nome='Barbearia Teste',
        servicos=[{'nome': 'Corte', 'duracao': 30, 'preco': 50.0}],
        data_hora=timezone.now() + timedelta(hours=12),
        duracao_total=30,
        valor_total=Decimal('50.00'),
        status='agendado',
    )


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestCadastroConsumidor:
    def test_cadastro_valido_retorna_201_e_access_token(self, api_anonimo):
        response = api_anonimo.post('/api/sm/auth/cadastro/', {
            'nome': 'Ana Lima',
            'email': 'ana@sm.com',
            'senha': 'SenhaForte123!',
            'telefone': '11999990000',
        })
        assert response.status_code == 201
        assert 'access' in response.data

    def test_cadastro_valido_seta_cookie_sm_refresh_token(self, api_anonimo):
        response = api_anonimo.post('/api/sm/auth/cadastro/', {
            'nome': 'Ana Lima',
            'email': 'ana@sm.com',
            'senha': 'SenhaForte123!',
            'telefone': '11999990000',
        })
        assert response.cookies.get('sm_refresh_token') is not None

    def test_cadastro_sem_telefone_retorna_400(self, api_anonimo):
        response = api_anonimo.post('/api/sm/auth/cadastro/', {
            'nome': 'Ana Lima',
            'email': 'ana@sm.com',
            'senha': 'SenhaForte123!',
        })
        assert response.status_code == 400

    def test_cadastro_email_duplicado_retorna_400(self, api_anonimo, consumidor):
        response = api_anonimo.post('/api/sm/auth/cadastro/', {
            'nome': 'Outro',
            'email': 'joao@sm.com',
            'senha': 'SenhaForte123!',
        })
        assert response.status_code == 400

    def test_cadastro_senha_curta_retorna_400(self, api_anonimo):
        response = api_anonimo.post('/api/sm/auth/cadastro/', {
            'nome': 'Fraco',
            'email': 'fraco@sm.com',
            'senha': '123',
        })
        assert response.status_code == 400

    def test_cadastro_email_invalido_retorna_400(self, api_anonimo):
        response = api_anonimo.post('/api/sm/auth/cadastro/', {
            'nome': 'Inv',
            'email': 'nao-e-email',
            'senha': 'SenhaForte123!',
        })
        assert response.status_code == 400


@pytest.mark.django_db
class TestLoginConsumidor:
    def test_login_correto_retorna_200_e_access_token(self, api_anonimo, consumidor):
        response = api_anonimo.post('/api/sm/auth/login/', {
            'email': 'joao@sm.com',
            'senha': 'SenhaForte123!',
        })
        assert response.status_code == 200
        assert 'access' in response.data
        assert response.cookies.get('sm_refresh_token') is not None

    def test_login_senha_errada_retorna_401(self, api_anonimo, consumidor):
        response = api_anonimo.post('/api/sm/auth/login/', {
            'email': 'joao@sm.com',
            'senha': 'errada',
        })
        assert response.status_code == 401

    def test_login_email_inexistente_retorna_401(self, api_anonimo):
        response = api_anonimo.post('/api/sm/auth/login/', {
            'email': 'nao@existe.com',
            'senha': 'SenhaForte123!',
        })
        assert response.status_code == 401


@pytest.mark.django_db
class TestRefreshLogoutConsumidor:
    def test_refresh_sem_cookie_retorna_401(self, api_anonimo):
        response = api_anonimo.post('/api/sm/auth/refresh/')
        assert response.status_code == 401

    def test_refresh_com_cookie_invalido_retorna_401(self, api_anonimo):
        api_anonimo.cookies['sm_refresh_token'] = 'token_invalido'
        response = api_anonimo.post('/api/sm/auth/refresh/')
        assert response.status_code == 401

    def test_logout_retorna_200_e_deleta_cookie(self, api_anonimo):
        response = api_anonimo.post('/api/sm/auth/logout/')
        assert response.status_code == 200
        assert 'sm_refresh_token' in response.cookies


# ---------------------------------------------------------------------------
# Perfil
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestMeuPerfil:
    def test_me_sem_auth_retorna_401(self, api_anonimo):
        response = api_anonimo.get('/api/sm/me/')
        assert response.status_code == 401

    def test_me_retorna_dados_do_consumidor(self, api_autenticado):
        client, consumidor = api_autenticado
        response = client.get('/api/sm/me/')
        assert response.status_code == 200
        assert response.data['nome'] == consumidor.nome
        assert response.data['email'] == consumidor.email


# ---------------------------------------------------------------------------
# Agendamentos
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestMeusAgendamentos:
    def test_lista_agendamentos_proprios(self, api_autenticado, agendamento_ativo):
        client, _ = api_autenticado
        response = client.get('/api/sm/agendamentos/')
        assert response.status_code == 200
        assert response.data['count'] == 1
        assert response.data['results'][0]['negocio_nome'] == 'Barbearia Teste'

    def test_logo_url_vem_do_negocio_publico(self, api_autenticado, agendamento_ativo):
        client, _ = api_autenticado
        NegocioPublico.objects.create(
            schema_name=agendamento_ativo.schema_name, nome='Barbearia Teste', nicho='Barbearia',
            latitude='-23.5', longitude='-46.6', logo_url='https://cdn/logo.png', ativo=True,
        )
        response = client.get('/api/sm/agendamentos/')
        assert response.data['results'][0]['logo_url'] == 'https://cdn/logo.png'

    def test_logo_url_nulo_quando_negocio_nao_tem_logo(self, api_autenticado, agendamento_ativo):
        client, _ = api_autenticado
        NegocioPublico.objects.create(
            schema_name=agendamento_ativo.schema_name, nome='Barbearia Teste', nicho='Barbearia',
            latitude='-23.5', longitude='-46.6', logo_url='', ativo=True,
        )
        response = client.get('/api/sm/agendamentos/')
        assert response.data['results'][0]['logo_url'] is None

    def test_logo_url_nulo_quando_negocio_saiu_da_vitrine(self, api_autenticado, agendamento_ativo):
        """O agendamento sobrevive ao negocio deixar a vitrine — a tela nao pode
        quebrar por causa da logo faltando."""
        client, _ = api_autenticado
        response = client.get('/api/sm/agendamentos/')
        assert response.data['results'][0]['logo_url'] is None

    def test_logo_resolvida_em_uma_consulta_para_a_pagina_inteira(self, api_autenticado, consumidor):
        """Guarda contra N+1: a consulta de logo nao pode crescer com o numero
        de agendamentos da pagina."""
        client, _ = api_autenticado
        for i in range(3):
            NegocioPublico.objects.create(
                schema_name=f'negocio_{i}', nome=f'N{i}', nicho='Barbearia',
                latitude='-23.5', longitude='-46.6', logo_url=f'https://cdn/{i}.png', ativo=True,
            )
            AgendamentoConsumidor.objects.create(
                consumidor=consumidor, schema_name=f'negocio_{i}', agendamento_id=i + 1,
                negocio_nome=f'N{i}', servicos=[],
                data_hora=timezone.now() + timedelta(hours=1),
                duracao_total=30, valor_total=Decimal('50.00'), status='agendado',
            )

        with CaptureQueriesContext(connection) as ctx:
            response = client.get('/api/sm/agendamentos/')

        assert response.data['count'] == 3
        consultas_logo = [q for q in ctx.captured_queries if 'vitrine_negociopublico' in q['sql']]
        assert len(consultas_logo) == 1

    def test_nao_retorna_agendamentos_de_outro_consumidor(self, api_autenticado, db):
        client, _ = api_autenticado
        outro_consumidor = RegistroConsumidorService().registrar(
            nome='Outro', email='outro@sm.com', senha='SenhaForte123!',
        )
        AgendamentoConsumidor.objects.create(
            consumidor=outro_consumidor,
            schema_name='outro_schema',
            agendamento_id=1,
            negocio_nome='Outro Negócio',
            servicos=[],
            data_hora=timezone.now() + timedelta(hours=1),
            duracao_total=30,
            valor_total=Decimal('50.00'),
            status='agendado',
        )
        response = client.get('/api/sm/agendamentos/')
        assert response.status_code == 200
        assert response.data['count'] == 0

    def test_filtra_agendamentos_por_status(self, api_autenticado, consumidor):
        client, _ = api_autenticado
        AgendamentoConsumidor.objects.create(
            consumidor=consumidor,
            schema_name='s1',
            agendamento_id=1,
            negocio_nome='N1',
            servicos=[],
            data_hora=timezone.now() + timedelta(hours=1),
            duracao_total=30,
            valor_total=Decimal('50.00'),
            status='agendado',
        )
        AgendamentoConsumidor.objects.create(
            consumidor=consumidor,
            schema_name='s2',
            agendamento_id=2,
            negocio_nome='N2',
            servicos=[],
            data_hora=timezone.now() + timedelta(hours=1),
            duracao_total=30,
            valor_total=Decimal('50.00'),
            status='cancelado',
        )
        response = client.get('/api/sm/agendamentos/?status=agendado')
        assert response.status_code == 200
        assert response.data['count'] == 1
        assert response.data['results'][0]['status'] == 'agendado'

    def test_agendamentos_sem_auth_retorna_401(self, api_anonimo):
        response = api_anonimo.get('/api/sm/agendamentos/')
        assert response.status_code == 401



@pytest.mark.django_db
class TestCancelarAgendamento:
    def test_cancelar_chama_service_e_retorna_taxa(self, api_autenticado, agendamento_ativo):
        client, consumidor = api_autenticado
        # Patch no módulo de origem pois a view faz import local dentro do método
        with patch('apps_serv.vitrine.services.CancelarAgendamentoService') as MockSvc:
            MockSvc.return_value.cancelar.return_value = {'taxa': 0.0}
            response = client.post(f'/api/sm/agendamentos/{agendamento_ativo.id}/cancelar/')
        assert response.status_code == 200
        assert response.data['taxa'] == 0.0

    def test_cancelar_agendamento_inexistente_retorna_404(self, api_autenticado):
        client, _ = api_autenticado
        response = client.post('/api/sm/agendamentos/9999/cancelar/')
        assert response.status_code == 404

    def test_cancelar_sem_auth_retorna_401(self, api_anonimo, agendamento_ativo):
        response = api_anonimo.post(f'/api/sm/agendamentos/{agendamento_ativo.id}/cancelar/')
        assert response.status_code == 401


# --- Foto do perfil do consumidor ---

SALVAR_FOTO = 'apps_work.empresa.services.ArmazenamentoImagemService.salvar'
URL_FOTO = 'apps_work.empresa.services.ArmazenamentoImagemService.url'
APAGAR_FOTO = 'apps_work.empresa.services.ArmazenamentoImagemService.apagar'


def _arquivo_imagem(nome='foto.png', tipo='image/png', tamanho=2048):
    from django.core.files.uploadedfile import SimpleUploadedFile
    return SimpleUploadedFile(nome, b'x' * tamanho, content_type=tipo)


@pytest.mark.django_db
class TestFotoPerfilAPI:
    URL = '/api/sm/me/foto/'

    def test_exige_autenticacao(self, api_anonimo):
        resposta = api_anonimo.post(self.URL, {'foto': _arquivo_imagem()}, format='multipart')
        assert resposta.status_code == 401

    def test_sem_arquivo_retorna_400(self, api_autenticado):
        client, _ = api_autenticado
        assert client.post(self.URL, {}, format='multipart').status_code == 400

    def test_arquivo_que_nao_e_imagem_e_recusado(self, api_autenticado):
        client, _ = api_autenticado
        pdf = _arquivo_imagem(nome='doc.pdf', tipo='application/pdf')
        assert client.post(self.URL, {'foto': pdf}, format='multipart').status_code == 400

    def test_upload_guarda_a_chave_e_nao_a_url(self, api_autenticado):
        """Guardar a URL faria a foto parar de abrir quando a assinatura vence."""
        client, consumidor = api_autenticado
        with patch(SALVAR_FOTO, return_value='consumidores/abc.webp'),              patch(URL_FOTO, return_value='https://x/assinada'):
            resposta = client.post(self.URL, {'foto': _arquivo_imagem()}, format='multipart')

        assert resposta.status_code == 200
        consumidor.refresh_from_db()
        assert consumidor.foto_chave == 'consumidores/abc.webp'

    def test_resposta_devolve_a_url_assinada(self, api_autenticado):
        client, _ = api_autenticado
        with patch(SALVAR_FOTO, return_value='consumidores/abc.webp'),              patch(URL_FOTO, return_value='https://x/assinada'):
            resposta = client.post(self.URL, {'foto': _arquivo_imagem()}, format='multipart')
        assert resposta.data['foto'] == 'https://x/assinada'

    def test_a_chave_nao_usa_id_sequencial(self, api_autenticado):
        """Id em sequencia no endereco permitiria varrer a foto de todo mundo."""
        import uuid as _uuid

        client, _ = api_autenticado
        with patch(SALVAR_FOTO, return_value='consumidores/abc.webp') as salvar,              patch(URL_FOTO, return_value=''):
            client.post(self.URL, {'foto': _arquivo_imagem()}, format='multipart')

        _uuid.UUID(salvar.call_args.kwargs['chave'])  # levanta se nao for UUID

    def test_enviar_de_novo_apaga_a_anterior(self, api_autenticado):
        client, consumidor = api_autenticado
        consumidor.foto_chave = 'consumidores/velha.webp'
        consumidor.save(update_fields=['foto_chave'])

        with patch(SALVAR_FOTO, return_value='consumidores/nova.webp'),              patch(URL_FOTO, return_value=''), patch(APAGAR_FOTO) as apagar:
            client.post(self.URL, {'foto': _arquivo_imagem()}, format='multipart')

        assert apagar.call_args.args[0] == 'consumidores/velha.webp'

    def test_remover_limpa_a_chave(self, api_autenticado):
        client, consumidor = api_autenticado
        consumidor.foto_chave = 'consumidores/abc.webp'
        consumidor.save(update_fields=['foto_chave'])

        with patch(APAGAR_FOTO), patch(URL_FOTO, return_value=''):
            resposta = client.delete(self.URL)

        assert resposta.status_code == 200
        consumidor.refresh_from_db()
        assert consumidor.foto_chave == ''


# ---------------------------------------------------------------------------
# GET /api/sm/vinculos/
# ---------------------------------------------------------------------------

def _negocio(schema_name: str, nome: str, **extra) -> NegocioPublico:
    return NegocioPublico.objects.create(
        schema_name=schema_name, nome=nome, nicho='Barbearia',
        latitude='-23.5', longitude='-46.6', ativo=True, **extra,
    )


@pytest.mark.django_db
class TestMeusVinculos:
    URL = '/api/sm/vinculos/'

    def test_retorna_o_negocio_resolvido(self, api_autenticado, consumidor):
        client, _ = api_autenticado
        _negocio('barbearia_a', 'Barbearia A', logo_url='https://cdn/a.png')
        VinculoConsumidor.objects.create(consumidor=consumidor, schema_name='barbearia_a')

        resposta = client.get(self.URL)

        assert resposta.status_code == 200
        assert len(resposta.data['results']) == 1
        assert resposta.data['results'][0]['nome'] == 'Barbearia A'
        assert resposta.data['results'][0]['logo_url'] == 'https://cdn/a.png'

    def test_mantem_schema_name_na_resposta(self, api_autenticado, consumidor):
        """A tela de perfil usa schema_name para saber se ja esta vinculada."""
        client, _ = api_autenticado
        _negocio('barbearia_a', 'Barbearia A')
        VinculoConsumidor.objects.create(consumidor=consumidor, schema_name='barbearia_a')

        resposta = client.get(self.URL)

        assert resposta.data['results'][0]['schema_name'] == 'barbearia_a'

    def test_informa_quando_o_vinculo_foi_criado(self, api_autenticado, consumidor):
        client, _ = api_autenticado
        _negocio('barbearia_a', 'Barbearia A')
        VinculoConsumidor.objects.create(consumidor=consumidor, schema_name='barbearia_a')

        resposta = client.get(self.URL)

        assert resposta.data['results'][0]['vinculado_em'] is not None

    def test_ignora_vinculo_cujo_negocio_saiu_da_vitrine(self, api_autenticado, consumidor):
        client, _ = api_autenticado
        VinculoConsumidor.objects.create(consumidor=consumidor, schema_name='negocio_sumiu')

        resposta = client.get(self.URL)

        assert resposta.data['results'] == []

    def test_nao_retorna_vinculo_inativo(self, api_autenticado, consumidor):
        client, _ = api_autenticado
        _negocio('barbearia_a', 'Barbearia A')
        VinculoConsumidor.objects.create(consumidor=consumidor, schema_name='barbearia_a', ativo=False)

        resposta = client.get(self.URL)

        assert resposta.data['results'] == []

    def test_nao_retorna_vinculo_de_outro_consumidor(self, api_autenticado, db):
        client, _ = api_autenticado
        outro = RegistroConsumidorService().registrar(
            nome='Outro', email='outro-vinc@sm.com', senha='SenhaForte123!',
        )
        _negocio('barbearia_a', 'Barbearia A')
        VinculoConsumidor.objects.create(consumidor=outro, schema_name='barbearia_a')

        resposta = client.get(self.URL)

        assert resposta.data['results'] == []

    def test_resolve_em_uma_consulta_independente_da_quantidade(self, api_autenticado, consumidor):
        """Guarda contra N+1: a consulta de negocios nao pode crescer com o
        numero de vinculos."""
        client, _ = api_autenticado
        for i in range(3):
            _negocio(f'negocio_{i}', f'N{i}')
            VinculoConsumidor.objects.create(consumidor=consumidor, schema_name=f'negocio_{i}')

        with CaptureQueriesContext(connection) as ctx:
            resposta = client.get(self.URL)

        assert len(resposta.data['results']) == 3
        consultas = [q for q in ctx.captured_queries if 'vitrine_negociopublico' in q['sql']]
        assert len(consultas) == 1
