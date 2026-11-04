from django.db import migrations

from core.rls import aplicar_politicas, remover_politicas


class Migration(migrations.Migration):
    """Liga o Row Level Security em toda tabela de negócio (ver core/rls.py).

    Depende da migration inicial de cada app de negócio: as políticas são
    geradas a partir das tabelas que existem neste ponto da história.
    """

    dependencies = [
        ('tenants', '0002_alter_tenant_schema_name'),
        ('usuarios', '0001_rls_initial'),
        ('clientes', '0001_rls_initial'),
        ('agenda', '0001_rls_initial'),
        ('servicos', '0001_rls_initial'),
        ('financeiro', '0001_rls_initial'),
        ('empresa', '0001_rls_initial'),
        ('kanban', '0001_rls_initial'),
        ('contratos', '0001_rls_initial'),
        ('notificacoes', '0001_rls_initial'),
    ]

    operations = [
        migrations.RunPython(aplicar_politicas, remover_politicas),
    ]
