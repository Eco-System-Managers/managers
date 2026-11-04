"""Row Level Security: a rede de segurança do isolamento entre negócios.

O manager (`core.tenant.TenantManager`) filtra toda consulta do ORM pelo
tenant atual. As políticas daqui fazem o Postgres repetir esse filtro para
qualquer SQL — ORM, `cursor.execute`, psql — comparando `tenant_id` com o
`app.tenant_id` que `com_tenant` grava na sessão. Sem tenant gravado, a
tabela parece vazia.

As políticas são geradas a partir dos modelos, para não existir tabela de
negócio sem política:

- modelo com `tenant`: compara a própria coluna;
- filho de herança multi-tabela (Veiculo, Pet): segue o ponteiro ao pai;
- tabela de ManyToMany: segue a FK ao modelo dono.

`aplicar_politicas` é idempotente: uma migration nova que crie tabela de
negócio pode chamá-la de novo.

Duas ressalvas, que ficam por conta do ambiente:

- superusuário do Postgres ignora RLS, mesmo com FORCE. O usuário da
  aplicação precisa ser um role comum (dono das tabelas serve: FORCE cobre
  o dono);
- `app.rls_bypass = 'on'` (ver `core.tenant.sem_isolamento`) desliga o
  filtro na sessão: é o que as exclusões em cascata que atravessam negócios
  usam (apagar um User que é colaborador em dois negócios).
"""
from django.apps import apps as registro_global

APPS_DE_NEGOCIO = (
    'usuarios', 'clientes', 'agenda', 'servicos', 'financeiro',
    'empresa', 'kanban', 'contratos', 'notificacoes',
)

NOME_POLITICA = 'isolamento_tenant'

_TENANT_ATUAL = "NULLIF(current_setting('app.tenant_id', true), '')::bigint"
_BYPASS = "current_setting('app.rls_bypass', true) = 'on'"


def _condicao_direta() -> str:
    return f'({_BYPASS} OR tenant_id = {_TENANT_ATUAL})'


def _condicao_via(tabela_pai: str, coluna_fk: str) -> str:
    return (
        f'({_BYPASS} OR EXISTS (SELECT 1 FROM "{tabela_pai}" pai '
        f'WHERE pai.id = "{coluna_fk}" AND pai.tenant_id = {_TENANT_ATUAL}))'
    )


def _tabelas_e_condicoes(apps=None) -> list[tuple[str, str]]:
    """(tabela, condição SQL) de toda tabela de negócio."""
    apps = apps or registro_global
    resultado = []
    for label in APPS_DE_NEGOCIO:
        for modelo in apps.get_app_config(label).get_models():
            opts = modelo._meta
            if opts.proxy:
                continue
            campos_locais = {f.name for f in opts.local_fields}
            if 'tenant' in campos_locais:
                resultado.append((opts.db_table, _condicao_direta()))
            elif opts.parents:
                pai, ponteiro = next(iter(opts.parents.items()))
                resultado.append((opts.db_table, _condicao_via(pai._meta.db_table, ponteiro.column)))
            for m2m in opts.local_many_to_many:
                through = m2m.remote_field.through._meta
                if through.auto_created:
                    coluna = f'{opts.model_name}_id'
                    resultado.append((through.db_table, _condicao_via(opts.db_table, coluna)))
    return resultado


def sql_aplicar(apps=None) -> list[str]:
    comandos = []
    for tabela, condicao in _tabelas_e_condicoes(apps):
        comandos += [
            f'ALTER TABLE "{tabela}" ENABLE ROW LEVEL SECURITY',
            f'ALTER TABLE "{tabela}" FORCE ROW LEVEL SECURITY',
            f'DROP POLICY IF EXISTS {NOME_POLITICA} ON "{tabela}"',
            f'CREATE POLICY {NOME_POLITICA} ON "{tabela}" USING {condicao} WITH CHECK {condicao}',
        ]
    return comandos


def sql_remover(apps=None) -> list[str]:
    comandos = []
    for tabela, _ in _tabelas_e_condicoes(apps):
        comandos += [
            f'DROP POLICY IF EXISTS {NOME_POLITICA} ON "{tabela}"',
            f'ALTER TABLE "{tabela}" NO FORCE ROW LEVEL SECURITY',
            f'ALTER TABLE "{tabela}" DISABLE ROW LEVEL SECURITY',
        ]
    return comandos


def aplicar_politicas(apps, schema_editor):
    for comando in sql_aplicar(apps):
        schema_editor.execute(comando)


def remover_politicas(apps, schema_editor):
    for comando in sql_remover(apps):
        schema_editor.execute(comando)
