import pytest
from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import override_settings

from core.middleware import TenantMiddleware
from core.tenant import com_tenant
from tenants.models import Tenant, Domain, Membro


@pytest.fixture(autouse=True)
def limpar_rate_limit():
    """Zera os contadores de rate limit (e o resto do cache) entre testes.

    Os throttles não são desligados: o DRF fixa `throttle_classes` quando
    `rest_framework.views` é importado, e desligar por settings fazia o
    resultado depender de qual teste importava as views primeiro.
    """
    from django.core.cache import cache
    cache.clear()


@pytest.fixture(autouse=True)
def tasks_imediatas(settings):
    """Tasks rodam na hora nos testes; fora deles, numa thread (core/tasks.py)."""
    settings.TASKS = {'default': {'BACKEND': 'django.tasks.backends.immediate.ImmediateBackend'}}


@pytest.fixture
def tenant(db):
    """O negócio de teste, ativo durante o teste inteiro.

    Dentro do `with` o manager dos modelos de negócio filtra por ele e a
    conexão carrega o `app.tenant_id` das políticas de RLS — o mesmo estado
    de uma requisição que passou pelo TenantMiddleware. Nada de schema físico:
    a linha do tenant e as tabelas vivem todas no `public`.
    """
    tenant = Tenant.objects.create(schema_name='test_empresa', nome='Empresa Teste')
    Domain.objects.get_or_create(
        domain='test-empresa.localhost',
        defaults={'tenant': tenant, 'is_primary': True},
    )
    with com_tenant(tenant):
        yield tenant


@pytest.fixture
def patch_tenant_middleware(tenant):
    """Simula requisições reais de HTTP chegando ao negócio de teste.

    O TenantMiddleware resolve o tenant pelo Host ou pelo JWT; o cliente de
    teste não manda nenhum dos dois, então a resolução pelo Host é substituída
    pelo tenant de teste.

    Como essas requisições passam pela stack de middleware completa (incluindo
    o AssinaturaBloqueadaMiddleware), o tenant de teste precisa de uma
    Assinatura ativa — igual a um tenant real pós-onboarding — senão toda
    chamada à API tomaria 402, quebrando testes que não têm nada a ver com
    billing.
    """
    import datetime

    from apps_work.billing.models import Assinatura, Plano

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

    with override_settings(ALLOWED_HOSTS=['*']):
        with patch.object(TenantMiddleware, '_por_host', lambda _self, request: tenant):
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


@pytest.fixture
def proprietario(tenant, usuario):
    """O `usuario` como dono do tenant de teste — o vínculo que o cadastro cria.

    O papel vem do Membro; sem ele o IsProprietario nega.
    """
    Membro.objects.create(user=usuario, tenant=tenant, papel='proprietario')
    return usuario
