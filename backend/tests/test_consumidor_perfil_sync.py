import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from unittest.mock import patch

from django.db import connection
from django.test import override_settings
from django_tenants.middleware.main import TenantMainMiddleware
from django_tenants.utils import schema_context
from rest_framework.test import APIClient

from apps_serv.autenticacao.authentication import gerar_tokens
from apps_serv.consumidores.models import VinculoConsumidor
from apps_serv.consumidores.services import RegistroConsumidorService
from apps_work.clientes.models import Cliente

EMAIL = 'carlos@sm.com'


@pytest.fixture
def patch_public_middleware():
    """Mantém a conexão no schema público, como nas outras rotas do app."""
    def _process_request(_self, request):
        connection.set_schema_to_public()

    with override_settings(ALLOWED_HOSTS=['*']):
        with patch.object(TenantMainMiddleware, 'process_request', _process_request):
            yield


@pytest.fixture
def consumidor(db):
    return RegistroConsumidorService().registrar(
        nome='Carlos Cliente', email=EMAIL, senha='SenhaForte123!', telefone='11999990000',
    )


@pytest.fixture
def app_consumidor(patch_public_middleware, consumidor):
    access, _ = gerar_tokens(consumidor)
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {access}')
    return client


@pytest.fixture
def cliente_do_negocio(tenant, consumidor):
    """Cliente já existente no schema do negócio, espelho do consumidor."""
    with schema_context(tenant.schema_name):
        cliente = Cliente.objects.create(
            nome='Carlos', email=EMAIL, telefone='11888880000',
            origem=Cliente.ORIGEM_SERVICEMANAGE,
        )
    connection.set_schema_to_public()
    return cliente


@pytest.fixture
def vinculado(consumidor, tenant, cliente_do_negocio):
    VinculoConsumidor.objects.create(
        consumidor=consumidor, schema_name=tenant.schema_name, ativo=True,
    )
    return cliente_do_negocio


def _reler(tenant, cliente) -> Cliente:
    with schema_context(tenant.schema_name):
        return Cliente.objects.get(pk=cliente.pk)


@pytest.mark.django_db
class TestAtualizarPerfil:
    def test_patch_salva_o_nome(self, app_consumidor, consumidor):
        app_consumidor.patch('/api/sm/me/', {'nome': 'Carlos Silva'}, format='json')
        consumidor.refresh_from_db()
        assert consumidor.nome == 'Carlos Silva'

    def test_patch_salva_a_ficha_completa(self, app_consumidor, consumidor):
        app_consumidor.patch('/api/sm/me/', {
            'cpf': '123.456.789-01', 'data_nascimento': '1990-01-01',
            'cep': '13000-000', 'endereco': 'Rua A', 'numero_endereco': '618',
        }, format='json')
        consumidor.refresh_from_db()
        assert consumidor.cpf == '12345678901'

    def test_email_nao_e_alteravel(self, app_consumidor, consumidor):
        app_consumidor.patch('/api/sm/me/', {'email': 'outro@sm.com'}, format='json')
        consumidor.refresh_from_db()
        assert consumidor.email == EMAIL

    def test_telefone_invalido_retorna_400(self, app_consumidor):
        response = app_consumidor.patch('/api/sm/me/', {'telefone': '119'}, format='json')
        assert response.status_code == 400

    def test_telefone_vazio_retorna_400(self, app_consumidor):
        response = app_consumidor.patch('/api/sm/me/', {'telefone': ''}, format='json')
        assert response.status_code == 400

    def test_cpf_invalido_retorna_400(self, app_consumidor):
        response = app_consumidor.patch('/api/sm/me/', {'cpf': '123'}, format='json')
        assert response.status_code == 400

    def test_sem_autenticacao_retorna_401(self, patch_public_middleware):
        response = APIClient().patch('/api/sm/me/', {'nome': 'X'}, format='json')
        assert response.status_code == 401


@pytest.mark.django_db
class TestSincronizacaoComOTenant:
    def test_nome_chega_no_cliente_do_negocio(self, app_consumidor, tenant, vinculado):
        app_consumidor.patch('/api/sm/me/', {'nome': 'Carlos Silva'}, format='json')
        assert _reler(tenant, vinculado).nome == 'Carlos Silva'

    def test_telefone_chega_no_cliente_do_negocio(self, app_consumidor, tenant, vinculado):
        app_consumidor.patch('/api/sm/me/', {'telefone': '11977770000'}, format='json')
        assert _reler(tenant, vinculado).telefone == '11977770000'

    def test_ficha_completa_chega_no_negocio(self, app_consumidor, tenant, vinculado):
        app_consumidor.patch('/api/sm/me/', {
            'cpf': '12345678901', 'endereco': 'Rua A', 'numero_endereco': '618',
        }, format='json')
        assert _reler(tenant, vinculado).cpf == '12345678901'

    def test_foto_chega_no_cliente_do_negocio(self, app_consumidor, tenant, vinculado):
        """O negócio vê a foto de quem se vinculou a ele — é dado da ficha,
        como nome e telefone, e chega pelo mesmo caminho."""
        from unittest.mock import patch as _patch

        with _patch('apps_work.empresa.services.ArmazenamentoImagemService.salvar',
                    return_value='consumidores/abc.webp'),              _patch('apps_work.empresa.services.ArmazenamentoImagemService.url', return_value=''):
            app_consumidor.post(
                '/api/sm/me/foto/',
                {'foto': SimpleUploadedFile('f.png', b'x' * 512, content_type='image/png')},
                format='multipart',
            )

        assert _reler(tenant, vinculado).foto_chave == 'consumidores/abc.webp'

    def test_remover_a_foto_limpa_no_negocio_tambem(self, app_consumidor, tenant, vinculado):
        """Desfazer no app precisa desfazer no painel — senão o negócio segue
        exibindo uma imagem que o dono dela já apagou."""
        from unittest.mock import patch as _patch

        with _patch('apps_work.empresa.services.ArmazenamentoImagemService.apagar'),              _patch('apps_work.empresa.services.ArmazenamentoImagemService.url', return_value=''):
            app_consumidor.delete('/api/sm/me/foto/')

        assert _reler(tenant, vinculado).foto_chave == ''

    def test_vinculo_inativo_nao_recebe(self, app_consumidor, consumidor, tenant, vinculado):
        VinculoConsumidor.objects.filter(consumidor=consumidor).update(ativo=False)

        app_consumidor.patch('/api/sm/me/', {'nome': 'Carlos Silva'}, format='json')

        assert _reler(tenant, vinculado).nome == 'Carlos'

    def test_tenant_fora_do_ar_nao_derruba_o_salvamento(self, app_consumidor, tenant, vinculado):
        alvo = 'django_tenants.utils.schema_context'
        with patch(alvo, side_effect=Exception('schema fora do ar')):
            response = app_consumidor.patch('/api/sm/me/', {'nome': 'Carlos Silva'}, format='json')

        assert response.status_code == 200


@pytest.mark.django_db
class TestPainelNaoEditaCadastroDoCliente:
    @pytest.fixture
    def painel(self, patch_tenant_middleware, proprietario):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        client.force_authenticate(user=proprietario)
        return client

    def test_painel_nao_altera_campo_sincronizado(self, painel):
        cliente = Cliente.objects.create(
            nome='Do app', email=EMAIL, telefone='11999990000',
            origem=Cliente.ORIGEM_SERVICEMANAGE,
        )

        painel.patch(f'/api/clientes/{cliente.pk}/', {'nome': 'Editado'}, format='json')

        cliente.refresh_from_db()
        assert cliente.nome == 'Do app'

    def test_painel_ainda_edita_observacao_do_cliente_do_app(self, painel):
        cliente = Cliente.objects.create(
            nome='Do app', email=EMAIL, telefone='11999990000',
            origem=Cliente.ORIGEM_SERVICEMANAGE,
        )

        painel.patch(
            f'/api/clientes/{cliente.pk}/',
            {'nome': 'Editado', 'observacao': 'Prefere manha'},
            format='json',
        )

        cliente.refresh_from_db()
        assert cliente.observacao == 'Prefere manha'

    def test_painel_edita_cliente_do_balcao_normalmente(self, painel):
        cliente = Cliente.objects.create(nome='Do balcao', telefone='11999990000')

        response = painel.patch(f'/api/clientes/{cliente.pk}/', {'nome': 'Editado'}, format='json')

        assert response.status_code == 200
