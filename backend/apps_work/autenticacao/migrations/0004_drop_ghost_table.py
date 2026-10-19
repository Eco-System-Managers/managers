from django.db import migrations


class Migration(migrations.Migration):
    """Remove a ghost table criada quando o app label era 'autenticacao' (antes de
    ser renomeado para 'autenticacao_work'). A tabela antiga bloqueia o TRUNCATE
    de auth_user durante o flush dos testes transacionais."""

    dependencies = [
        ('autenticacao_work', '0003_alter_codigorecuperacao_codigo'),
    ]

    operations = [
        migrations.RunSQL(
            sql='DROP TABLE IF EXISTS public."autenticacao_codigorecuperacao" CASCADE',
            reverse_sql='',
        ),
    ]
