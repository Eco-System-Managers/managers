import pytest
from unittest.mock import patch

from django.contrib.auth.models import User
from django.core.management import call_command
from django.db import connection
from django.test import TransactionTestCase, override_settings
from django_tenants.middleware.main import TenantMainMiddleware
from tenants.models import Tenant, Domain


@pytest.fixture(autouse=True, scope='session')
def _patch_transactional_flush():
    """Força TRUNCATE ... CASCADE no teardown de testes transacionais.

    O schema PUBLIC contém tabelas de TENANT apps criadas pelo manage.py migrate
    (ex: usuarios_colaborador, agenda_agendamento, …). Essas tabelas têm FKs para
    auth_user, mas Django não as inclui no TRUNCATE (por não serem SHARED apps) e
    o Django 6 não adiciona CASCADE por padrão. Sem CASCADE o flush falha.
    """
    def _fixture_teardown_with_cascade(self):
        for db in self._databases_names(include_mirrors=False):
            call_command(
                'flush',
                verbosity=0,
                interactive=False,
                database=db,
                reset_sequences=False,
                allow_cascade=True,
                inhibit_post_migrate=True,
            )

    original = TransactionTestCase._fixture_teardown
    TransactionTestCase._fixture_teardown = _fixture_teardown_with_cascade
    yield
    TransactionTestCase._fixture_teardown = original


@pytest.fixture(autouse=True)
def disable_throttling(settings):
    """Desabilita throttling para que testes não recebam 429 por rate limit."""
    from django.core.cache import cache
    settings.REST_FRAMEWORK = {
        **settings.REST_FRAMEWORK,
        'DEFAULT_THROTTLE_CLASSES': [],
    }
    cache.clear()


def _drop_tenant_schema(schema_name: str) -> None:
    """Derruba o schema PostgreSQL do tenant e remove as linhas de tenant/domain."""
    connection.set_schema_to_public()
    with connection.cursor() as cursor:
        # Força triggers deferidos a disparar agora; sem isso, DROP falha com
        # "cannot execute DROP TABLE because of pending trigger events"
        cursor.execute('SET CONSTRAINTS ALL IMMEDIATE')
        cursor.execute(f'DROP SCHEMA IF EXISTS "{schema_name}" CASCADE')
        # Remove a ghost table do schema PUBLIC criada quando o app label era
        # 'autenticacao' (antes de 'autenticacao_work'). Ela bloqueia o
        # TRUNCATE de auth_user no flush pós-teste transacional.
        # Nome schema-qualificado evita ambiguidade com search_path.
        cursor.execute('DROP TABLE IF EXISTS public."autenticacao_codigorecuperacao" CASCADE')
        cursor.execute('DROP TABLE IF EXISTS public."autenticacao_lastactivity" CASCADE')
    Tenant.objects.filter(schema_name=schema_name).delete()


@pytest.fixture
def tenant(db):
    connection.set_schema_to_public()

    # Limpa estado residual de runs anteriores que falharam no teardown.
    # auto_drop_schema=False no modelo, então usamos SQL direto para garantir
    # que o schema antigo (com tabelas legadas) não bloqueie o flush posterior.
    _drop_tenant_schema('test_empresa')

    tenant = Tenant.objects.create(
        schema_name='test_empresa',
        name='Empresa Teste',
    )
    connection.set_schema_to_public()
    Domain.objects.get_or_create(
        domain='test-empresa.localhost',
        defaults={'tenant': tenant, 'is_primary': True},
    )
    connection.set_tenant(tenant)
    yield tenant
    # Teardown: drop schema + linhas antes do flush do pytest-django.
    # Sem isso, o TRUNCATE do auth_user falharia por FK vindo do schema do tenant.
    _drop_tenant_schema('test_empresa')


@pytest.fixture
def patch_tenant_middleware(tenant):
    """Simula requisições reais de HTTP passando pelo TenantMainMiddleware.

    Como essas requisições passam pela stack de middleware completa (incluindo
    o AssinaturaBloqueadaMiddleware), o tenant de teste precisa de uma
    Assinatura ativa — igual a um tenant real pós-onboarding — senão toda
    chamada à API tomaria 402, quebrando testes que não têm nada a ver com
    billing.
    """
    import datetime

    from apps_work.billing.models import Assinatura, Plano

    def _process_request(_self, request):
        connection.set_schema_to_public()
        connection.set_tenant(tenant)
        request.tenant = tenant

    connection.set_schema_to_public()
    plano, _ = Plano.objects.get_or_create(nome='pro', defaults={'preco_mensal': '69.90'})
    Assinatura.objects.get_or_create(
        tenant=tenant,
        defaults={
            'plano': plano,
            'status': 'ativa',
            'inicio': datetime.date.today(),
            'proximo_vencimento': datetime.date.today() + datetime.timedelta(days=30),
        },
    )
    connection.set_tenant(tenant)

    with override_settings(ALLOWED_HOSTS=['*']):
        with patch.object(TenantMainMiddleware, 'process_request', _process_request):
            yield tenant


@pytest.fixture
def usuario(db):
    return User.objects.create_user(
        username='teste@email.com',
        email='teste@email.com',
        password='senha123',
        first_name='João',
        last_name='Silva',
    )
