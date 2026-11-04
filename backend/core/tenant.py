"""O tenant atual: quem é o negócio desta requisição, desta task ou deste comando.

Todas as tabelas de negócio vivem no schema público, com a coluna `tenant_id`.
Quem garante que um negócio não enxerga o outro são duas camadas:

1. **O manager.** Todo modelo de negócio herda de `TenantModel`; o `objects`
   filtra pelo tenant atual e preenche o `tenant` no `save`. Sem tenant no
   contexto, consultar é erro (`TenantIndefinido`), não lista vazia: a falha
   aparece em vez de passar despercebida.
2. **RLS no Postgres.** Cada tabela tem uma política que compara `tenant_id`
   com `current_setting('app.tenant_id')`. O `com_tenant` grava esse valor na
   sessão da conexão. Vale como rede de segurança para SQL direto e para o
   que escapar do manager; só é aplicada quando o usuário do banco não é
   superusuário (superusuário ignora RLS).

O tenant atual fica num `ContextVar`: é por thread (cada requisição e cada
task têm o seu) e aninha, voltando ao anterior ao sair do `with`.
"""
import contextvars
from contextlib import contextmanager

from django.db import connection, models

_tenant_atual = contextvars.ContextVar('tenant_atual', default=None)

CONFIG_TENANT = 'app.tenant_id'
CONFIG_BYPASS = 'app.rls_bypass'


class TenantIndefinido(RuntimeError):
    """Consulta a dado de negócio sem um tenant no contexto."""


def tenant_atual():
    """O Tenant da requisição/task atual, ou None fora de um `com_tenant`."""
    return _tenant_atual.get()


def schema_atual() -> str:
    """O slug do tenant atual, ou 'public' fora de um. Mantém o nome que o JWT,
    os links e as tabelas públicas usam (`schema_name`)."""
    tenant = tenant_atual()
    return tenant.schema_name if tenant is not None else 'public'


def exigir_tenant():
    tenant = tenant_atual()
    if tenant is None:
        raise TenantIndefinido('Nenhum tenant no contexto; use com_tenant().')
    return tenant


def _resolver(tenant_ou_slug):
    from tenants.models import Tenant

    if tenant_ou_slug is None or isinstance(tenant_ou_slug, Tenant):
        return tenant_ou_slug
    return Tenant.objects.get(schema_name=tenant_ou_slug)


def _set_config(nome: str, valor: str) -> None:
    """Grava uma variável na sessão do Postgres.

    Não é `SET LOCAL`: ele só vale dentro de uma transação, e `com_tenant`
    também é usado fora de uma (comandos, tasks). Numa transação que já
    falhou não há o que gravar: o Postgres recusa qualquer comando até o
    rollback, e o rollback desfaz o que foi gravado dentro dela.
    """
    if connection.in_atomic_block and connection.needs_rollback:
        return
    if connection.connection is None or connection.connection.closed:
        connection.ensure_connection()
    if _transacao_abortada():
        return
    with connection.cursor() as cursor:
        cursor.execute('SELECT set_config(%s, %s, false)', [nome, valor])


def _transacao_abortada() -> bool:
    """A transação atual já falhou e ainda não foi desfeita (psycopg2)."""
    try:
        from psycopg2.extensions import TRANSACTION_STATUS_INERROR

        return connection.connection.get_transaction_status() == TRANSACTION_STATUS_INERROR
    except Exception:
        return False


def _gravar_na_conexao(tenant) -> None:
    """Deixa o tenant na sessão do Postgres, para as políticas de RLS. O
    valor é desfeito na saída do `with`, então nunca sobra de uma requisição
    para a próxima na mesma conexão persistente."""
    _set_config(CONFIG_TENANT, '' if tenant is None else str(tenant.pk))


@contextmanager
def com_tenant(tenant_ou_slug):
    """Executa o bloco como o tenant dado (objeto ou `schema_name`).

    `None` sai de qualquer tenant: o que vale para o que é só do público
    (cadastro, login). Aninha: ao sair, o tenant anterior volta, no contexto e
    na conexão.
    """
    tenant = _resolver(tenant_ou_slug)
    anterior = _tenant_atual.get()
    token = _tenant_atual.set(tenant)
    # De público para público não há o que gravar: poupa a ida ao banco em
    # toda requisição sem tenant (login, cadastro, Service Manage).
    gravar = tenant is not None or anterior is not None
    if gravar:
        _gravar_na_conexao(tenant)
    try:
        yield tenant
    finally:
        _tenant_atual.reset(token)
        if gravar:
            _gravar_na_conexao(anterior)


@contextmanager
def sem_isolamento():
    """Desliga o RLS na sessão durante o bloco.

    Só para o que atravessa negócios de propósito e não passa pelo manager:
    apagar um User em cascata (ele pode ser colaborador em mais de um
    negócio), apagar um Tenant inteiro, a migração de dados. O manager
    continua filtrando; o que muda é o que o Postgres deixa a cascata e o
    `todos` enxergarem.
    """
    _set_config(CONFIG_BYPASS, 'on')
    try:
        yield
    finally:
        _set_config(CONFIG_BYPASS, '')


class TenantAtual(models.Expression):
    """O id do tenant atual, lido na hora de gerar o SQL, não na de montar a
    consulta. Assim um queryset montado fora de contexto (atributo de classe,
    `queryset=` de um serializer) ainda filtra pelo tenant certo em cada
    execução — e executar sem tenant é erro."""

    def __init__(self):
        super().__init__(output_field=models.BigIntegerField())

    def as_sql(self, compiler, connection):
        return '%s', [exigir_tenant().pk]


class TenantQuerySet(models.QuerySet):
    def bulk_create(self, objs, *args, **kwargs):
        # bulk_create não passa pelo save(): o tenant entra aqui.
        for obj in objs:
            if obj.tenant_id is None:
                obj.tenant = exigir_tenant()
        return super().bulk_create(objs, *args, **kwargs)


class TenantManager(models.Manager.from_queryset(TenantQuerySet)):
    """O manager padrão dos modelos de negócio: sempre o tenant atual."""

    def get_queryset(self):
        return super().get_queryset().filter(tenant_id=TenantAtual())


class TenantModel(models.Model):
    """Base de todo modelo que pertence a um negócio.

    `objects` enxerga só o tenant atual. `todos` enxerga todos os negócios:
    é para o admin, os comandos e a migração de dados, nunca para uma view.
    Seguir uma FK e apagar em cascata usam o base manager do Django, que é
    um `Manager()` comum: não dependem do contexto.
    """

    tenant = models.ForeignKey(
        'tenants.Tenant', on_delete=models.CASCADE, related_name='+', editable=False,
    )

    objects = TenantManager()
    todos = models.Manager()

    class Meta:
        abstract = True

    def save(self, *args, **kwargs):
        if self.tenant_id is None:
            self.tenant = exigir_tenant()
        super().save(*args, **kwargs)
