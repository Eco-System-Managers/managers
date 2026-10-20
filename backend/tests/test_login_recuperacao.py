"""Login, recuperação de senha e cadastro sem enumeração de e-mail (issue #11)."""
import smtplib
import threading
from unittest.mock import patch

import pytest
from django.contrib.auth.models import User
from django.tasks import task
from rest_framework.test import APIClient

from apps_serv.consumidores.models import CodigoRecuperacaoConsumidor
from apps_serv.consumidores.services import LoginConsumidorService, RegistroConsumidorService
from apps_work.autenticacao.models import CodigoRecuperacao
from apps_work.autenticacao.serializers import _slug, gerar_schema_name
from apps_work.autenticacao.services import RecuperacaoSenhaService, dominio_do_schema
from tenants.models import Domain


@pytest.fixture
def api(patch_tenant_middleware):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    return client


@pytest.fixture
def user_auth(db):
    return User.objects.create_user(
        username='auth@teste.com', email='auth@teste.com', password='SenhaForte123!',
    )


# ---------------------------------------------------------------------------
# Login em tempo constante
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestLoginSemEnumeracao:
    def test_b2b_calcula_hash_quando_o_usuario_nao_existe(self, api):
        with patch.object(User, 'set_password') as hash_ficticio:
            response = api.post('/api/v1/auth/login/', {'email': 'ninguem@teste.com', 'senha': 'qualquer'})
        assert response.status_code == 401
        hash_ficticio.assert_called_once_with('qualquer')

    def test_b2b_mantem_a_mensagem_de_usuario_inativo(self, api, proprietario):
        proprietario.is_active = False
        proprietario.save()
        response = api.post('/api/v1/auth/login/', {'email': proprietario.username, 'senha': 'senha123'})
        assert response.status_code == 403
        assert response.data['code'] == 'user_inactive'

    def test_b2b_credencial_errada_tem_o_mesmo_codigo_do_b2c(self, api, proprietario):
        response = api.post('/api/v1/auth/login/', {'email': proprietario.username, 'senha': 'errada'})
        assert response.status_code == 401
        assert response.data['code'] == 'credenciais_invalidas'

    def test_b2b_usuario_sem_empresa(self, api, user_auth):
        response = api.post('/api/v1/auth/login/', {'email': 'auth@teste.com', 'senha': 'SenhaForte123!'})
        assert response.status_code == 400
        assert response.data['code'] == 'sem_empresa'

    def test_b2c_calcula_hash_quando_o_consumidor_nao_existe(self, db):
        with patch('apps_serv.consumidores.services.make_password') as hash_ficticio:
            with pytest.raises(ValueError):
                LoginConsumidorService().autenticar(email='ninguem@sm.com', senha='qualquer')
        hash_ficticio.assert_called_once_with('qualquer')


# ---------------------------------------------------------------------------
# Recuperação de senha
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestRecuperacaoB2B:
    def test_codigo_fica_salvo_so_como_hash(self, user_auth):
        registro, codigo = CodigoRecuperacao.emitir(user_auth)
        assert codigo not in registro.codigo_hash
        assert registro.confere(codigo)
        assert not registro.confere('00000000')

    def test_busca_pelo_email_ignora_maiusculas(self, api, user_auth):
        with patch('core.email.send_mail') as mock_mail:
            api.post('/api/v1/auth/recuperar-senha/', {'email': 'AUTH@Teste.com'})
        mock_mail.assert_called_once()

    def test_email_repetido_em_outro_user_nao_quebra(self, api, user_auth):
        # O campo email do User não é único; antes isso dava MultipleObjectsReturned.
        User.objects.create_user(username='outro', email='auth@teste.com', password='x')
        with patch('core.email.send_mail'):
            response = api.post('/api/v1/auth/recuperar-senha/', {'email': 'auth@teste.com'})
        assert response.status_code == 200

    def test_erro_de_smtp_nao_aparece_na_resposta(self, api, user_auth):
        with patch('core.email.send_mail', side_effect=smtplib.SMTPException('fora do ar')):
            response = api.post('/api/v1/auth/recuperar-senha/', {'email': 'auth@teste.com'})
        assert response.status_code == 200
        assert response.data['detail'] == RecuperacaoSenhaService.GENERIC_MSG

    def test_codigo_bloqueia_apos_5_tentativas(self, api, user_auth):
        CodigoRecuperacao.emitir(user_auth, '12345678')
        for _ in range(CodigoRecuperacao.MAX_TENTATIVAS):
            api.post('/api/v1/auth/verificar-codigo/', {'email': 'auth@teste.com', 'codigo': '00000000'})

        response = api.post('/api/v1/auth/verificar-codigo/', {'email': 'auth@teste.com', 'codigo': '12345678'})
        assert response.status_code == 400

    def test_tentativa_errada_na_nova_senha_tambem_conta(self, api, user_auth):
        registro, _ = CodigoRecuperacao.emitir(user_auth, '12345678')
        api.post('/api/v1/auth/nova-senha/', {
            'email': 'auth@teste.com', 'codigo': '00000000', 'nova_senha': 'NovaSenha456!',
        })
        registro.refresh_from_db()
        assert registro.tentativas == 1

    def test_senha_fraca_nao_gasta_tentativa(self, api, user_auth):
        registro, _ = CodigoRecuperacao.emitir(user_auth, '12345678')
        response = api.post('/api/v1/auth/nova-senha/', {
            'email': 'auth@teste.com', 'codigo': '00000000', 'nova_senha': '123',
        })
        assert response.status_code == 400
        registro.refresh_from_db()
        assert registro.tentativas == 0

    def test_nova_senha_parecida_com_o_email_e_recusada(self, api, user_auth):
        CodigoRecuperacao.emitir(user_auth, '12345678')
        response = api.post('/api/v1/auth/nova-senha/', {
            'email': 'auth@teste.com', 'codigo': '12345678', 'nova_senha': 'auth@teste.com',
        })
        assert response.status_code == 400
        user_auth.refresh_from_db()
        assert user_auth.check_password('SenhaForte123!')


@pytest.mark.django_db
class TestRecuperacaoB2C:
    @pytest.fixture
    def consumidor(self, db):
        return RegistroConsumidorService().registrar(
            nome='Carla', email='carla@sm.com', senha='SenhaForte123!', telefone='11999990000',
        )

    def test_codigo_fica_salvo_so_como_hash(self, consumidor):
        registro, codigo = CodigoRecuperacaoConsumidor.emitir(consumidor)
        assert codigo not in registro.codigo_hash
        assert registro.confere(codigo)

    def test_erro_de_smtp_nao_aparece_na_resposta(self, consumidor):
        from apps_serv.consumidores.services import RecuperacaoSenhaConsumidorService
        with patch('core.email.send_mail', side_effect=smtplib.SMTPException('fora do ar')):
            msg = RecuperacaoSenhaConsumidorService().solicitar('carla@sm.com')
        assert msg == RecuperacaoSenhaConsumidorService.GENERIC_MSG


# ---------------------------------------------------------------------------
# Backend de tasks em thread
# ---------------------------------------------------------------------------

_threads_da_task = []
_task_terminou = threading.Event()


@task
def _registrar_thread() -> None:
    _threads_da_task.append(threading.get_ident())
    _task_terminou.set()


@pytest.mark.django_db
def test_thread_backend_executa_fora_da_thread_da_requisicao(settings, django_capture_on_commit_callbacks):
    settings.TASKS = {'default': {'BACKEND': 'core.tasks.ThreadBackend'}}
    _threads_da_task.clear()
    _task_terminou.clear()

    with django_capture_on_commit_callbacks(execute=True):
        _registrar_thread.enqueue()

    assert _task_terminou.wait(timeout=5)
    assert _threads_da_task == [_threads_da_task[0]]
    assert _threads_da_task[0] != threading.get_ident()


# ---------------------------------------------------------------------------
# Schema e domínio no cadastro
# ---------------------------------------------------------------------------

class TestSlugDoSchema:
    @pytest.mark.parametrize('nome, esperado', [
        ('Salão Bela', 'salao_bela'),
        ('  Barbearia -- do  Zé!! ', 'barbearia_do_ze'),
        ('123 Lanches', 'e_123_lanches'),
        ('pg_admin', 'e_pg_admin'),
        ('Public', 'e_public'),
        ('!!!', ''),
        ('洗车', ''),
    ])
    def test_slug(self, nome, esperado):
        assert _slug(nome) == esperado

    def test_nome_longo_cabe_no_limite_do_postgres_com_sufixo(self):
        slug = _slug('Empresa ' * 30)
        assert len(f'{slug}_999') <= 63
        assert not slug.endswith('_')

    def test_dominio_troca_underscore_por_hifen(self, settings):
        settings.TENANT_DOMAIN_SUFFIX = 'workmanage.com.br'
        assert dominio_do_schema('salao_bela_2') == 'salao-bela-2.workmanage.com.br'


@pytest.mark.django_db
class TestSchemaNoCadastro:
    def test_proximo_sufixo_livre(self, tenant):
        # O tenant de teste ocupa test_empresa.
        assert gerar_schema_name('Test Empresa') == 'test_empresa_2'

    def test_nome_sem_letra_nem_numero_retorna_400(self, api):
        response = api.post('/api/v1/auth/cadastro/', {
            'nome_empresa': '!!!', 'nome': 'Ana', 'email': 'ana@x.com', 'senha': 'SenhaForte123!',
        })
        assert response.status_code == 400
        assert 'nome_empresa' in response.data['fields']

    def test_cadastro_cria_dominio_valido(self, api):
        response = api.post('/api/v1/auth/cadastro/', {
            'nome_empresa': 'Salão Bela', 'nome': 'Ana', 'email': 'ana@x.com', 'senha': 'SenhaForte123!',
        })
        assert response.status_code == 201
        assert response.data['schema_name'] == 'salao_bela'
        assert Domain.objects.filter(domain='salao-bela.localhost').exists()
