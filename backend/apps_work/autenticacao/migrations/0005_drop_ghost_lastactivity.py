from django.db import migrations


class Migration(migrations.Migration):
    """Remove a ghost table 'autenticacao_lastactivity' criada quando o app label
    era 'autenticacao' (antes de 'autenticacao_work'). Bloqueia o TRUNCATE de
    auth_user durante o flush dos testes transacionais."""

    dependencies = [
        ('autenticacao_work', '0004_drop_ghost_table'),
    ]

    operations = [
        migrations.RunSQL(
            sql='DROP TABLE IF EXISTS public."autenticacao_lastactivity" CASCADE',
            reverse_sql='',
        ),
    ]
