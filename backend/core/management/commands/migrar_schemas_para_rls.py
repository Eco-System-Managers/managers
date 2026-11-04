"""Copia os dados dos schemas antigos (um por negócio) para as tabelas do
`public`, com `tenant_id`.

É o passo de dados da saída do django-tenants. Roda uma vez, depois do
`migrate` que criou as tabelas no `public`, e antes de o código novo entrar
no ar. Os schemas antigos ficam intactos: o rollback é voltar o deploy.

Como as chaves primárias de cada schema começam em 1, os ids colidiriam ao
juntar tudo. Cada negócio ganha um deslocamento fixo (`id do tenant × 10⁹`),
somado ao `id` e a toda FK entre tabelas de negócio — inclusive às que o
público guarda soltas (`AgendamentoConsumidor.agendamento_id`). FKs para o
público (`user_id`) ficam como estão.

Tudo roda numa transação só: qualquer erro desfaz tudo. Com `--dry-run` a
transação é desfeita no fim, com o relatório impresso.
"""
from django.apps import apps
from django.core.management.base import BaseCommand, CommandError
from django.db import connection, transaction

from core.rls import APPS_DE_NEGOCIO
from core.tenant import sem_isolamento

DESLOCAMENTO_POR_TENANT = 1_000_000_000


def _modelos_de_negocio():
    """Os modelos concretos dos apps de negócio, na ordem do registro."""
    for label in APPS_DE_NEGOCIO:
        for modelo in apps.get_app_config(label).get_models():
            if not modelo._meta.proxy:
                yield modelo


def _tabelas():
    """(tabela, colunas a deslocar, tem tenant_id) de toda tabela de negócio,
    tabelas de ManyToMany incluídas.

    Desloca o `id`, o ponteiro da herança multi-tabela e toda FK cujo alvo é
    outro modelo de negócio.
    """
    negocio = set(_modelos_de_negocio())
    resultado = []
    for modelo in negocio:
        opts = modelo._meta
        deslocar = []
        for campo in opts.local_fields:
            if campo.primary_key or (campo.is_relation and campo.remote_field.model in negocio):
                deslocar.append(campo.column)
        resultado.append((opts.db_table, deslocar, 'tenant' in {f.name for f in opts.local_fields}))
        for m2m in opts.local_many_to_many:
            through = m2m.remote_field.through._meta
            if through.auto_created:
                colunas = [f.column for f in through.local_fields]
                resultado.append((through.db_table, colunas, False))
    return resultado


class Command(BaseCommand):
    help = 'Copia os dados dos schemas antigos (django-tenants) para o public, com tenant_id.'

    def add_arguments(self, parser):
        parser.add_argument('--dry-run', action='store_true', help='faz tudo e desfaz no fim')
        parser.add_argument('--tenant', help='só este negócio (schema_name)')

    def handle(self, *args, dry_run, tenant, **options):
        from tenants.models import Tenant

        tenants = Tenant.objects.order_by('id')
        if tenant:
            tenants = tenants.filter(schema_name=tenant)
            if not tenants.exists():
                raise CommandError(f'Negócio {tenant!r} não existe.')

        tabelas = _tabelas()
        try:
            with sem_isolamento(), transaction.atomic():
                for t in tenants:
                    self._migrar(t, tabelas)
                self._ajustar_sequences(tabelas)
                if dry_run:
                    raise _Desfazer()
        except _Desfazer:
            self.stdout.write(self.style.WARNING('Dry run: nada foi gravado.'))
            return
        self.stdout.write(self.style.SUCCESS('Migração concluída.'))

    # ------------------------------------------------------------------

    def _migrar(self, tenant, tabelas):
        schema = tenant.schema_name
        if not self._schema_existe(schema):
            self.stdout.write(f'{schema}: sem schema antigo, nada a copiar.')
            return
        if self._ja_migrado(tenant, tabelas):
            self.stdout.write(f'{schema}: já tem dados no public, pulando.')
            return

        deslocamento = tenant.id * DESLOCAMENTO_POR_TENANT
        self.stdout.write(f'{schema} (tenant {tenant.id}, deslocamento {deslocamento}):')
        for tabela, deslocar, com_tenant_id in tabelas:
            if not self._tabela_existe(schema, tabela):
                # Tabela que só existe no modelo novo: nada a copiar.
                continue
            copiadas = self._copiar(schema, tabela, deslocar, com_tenant_id, tenant.id, deslocamento)
            origem = self._contar(f'"{schema}"."{tabela}"')
            if copiadas != origem:
                raise CommandError(f'{schema}.{tabela}: {origem} linhas na origem, {copiadas} copiadas.')
            self.stdout.write(f'  {tabela}: {copiadas}')

        self._deslocar_referencias_publicas(schema, deslocamento)

    def _copiar(self, schema, tabela, deslocar, com_tenant_id, tenant_id, deslocamento) -> int:
        colunas = self._colunas(schema, tabela)
        destino = [c for c in self._colunas('public', tabela) if c in colunas]
        expressoes = [f'"{c}" + %(d)s' if c in deslocar else f'"{c}"' for c in destino]
        colunas_insert = [f'"{c}"' for c in destino]
        if com_tenant_id:
            colunas_insert.append('tenant_id')
            expressoes.append('%(t)s')
        sql = (
            f'INSERT INTO public."{tabela}" ({", ".join(colunas_insert)}) '
            f'SELECT {", ".join(expressoes)} FROM "{schema}"."{tabela}"'
        )
        with connection.cursor() as cursor:
            cursor.execute(sql, {'d': deslocamento, 't': tenant_id})
            return cursor.rowcount

    def _deslocar_referencias_publicas(self, schema, deslocamento):
        """O app do cliente guarda o id do agendamento (ou do atendimento da
        esteira) solto, por schema: segue o mesmo deslocamento."""
        with connection.cursor() as cursor:
            cursor.execute(
                'UPDATE public.consumidores_agendamentoconsumidor '
                'SET agendamento_id = agendamento_id + %s WHERE schema_name = %s',
                [deslocamento, schema],
            )
            self.stdout.write(f'  consumidores_agendamentoconsumidor (referências): {cursor.rowcount}')

    def _ajustar_sequences(self, tabelas):
        """As sequences continuam de onde pararam em cada schema; aqui passam
        a continuar do maior id já ocupado no public."""
        with connection.cursor() as cursor:
            for tabela, deslocar, _ in tabelas:
                if 'id' not in deslocar:
                    # Filha de herança multi-tabela: a chave é o ponteiro ao pai.
                    continue
                cursor.execute(
                    f"SELECT setval(pg_get_serial_sequence('public.{tabela}', 'id'), "
                    f'GREATEST(COALESCE(MAX(id), 0), 1)) FROM public."{tabela}"'
                )

    # ------------------------------------------------------------------

    def _ja_migrado(self, tenant, tabelas) -> bool:
        with connection.cursor() as cursor:
            for tabela, _, com_tenant_id in tabelas:
                if not com_tenant_id:
                    continue
                cursor.execute(f'SELECT 1 FROM public."{tabela}" WHERE tenant_id = %s LIMIT 1', [tenant.id])
                if cursor.fetchone():
                    return True
        return False

    def _schema_existe(self, schema) -> bool:
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1 FROM information_schema.schemata WHERE schema_name = %s', [schema])
            return cursor.fetchone() is not None

    def _tabela_existe(self, schema, tabela) -> bool:
        with connection.cursor() as cursor:
            cursor.execute(
                'SELECT 1 FROM information_schema.tables WHERE table_schema = %s AND table_name = %s',
                [schema, tabela],
            )
            return cursor.fetchone() is not None

    def _colunas(self, schema, tabela) -> list[str]:
        with connection.cursor() as cursor:
            cursor.execute(
                'SELECT column_name FROM information_schema.columns '
                'WHERE table_schema = %s AND table_name = %s ORDER BY ordinal_position',
                [schema, tabela],
            )
            return [linha[0] for linha in cursor.fetchall()]

    def _contar(self, tabela_qualificada) -> int:
        with connection.cursor() as cursor:
            cursor.execute(f'SELECT COUNT(*) FROM {tabela_qualificada}')
            return cursor.fetchone()[0]


class _Desfazer(Exception):
    """Sai da transação do dry run sem gravar."""
