from django.db import migrations


def marcar_origem_servicemanage(apps, schema_editor):
    """Backfill de `origem` para os cadastros que já vieram do Service Manage.

    A 0007 criou o campo com default 'manual', então todo cliente vinculado que
    já existia ficaria marcado como manual — e removê-lo pelo painel só o
    arquivaria, deixando o VinculoConsumidor ativo no schema público. O negócio
    continuaria em "Seus negócios" pro consumidor e o cliente ressurgiria na
    lista no próximo agendamento (garantir_vinculo).

    `clientes` é TENANT_APP e `consumidores` é SHARED_APP: esta função roda uma
    vez por schema e alcança as tabelas do público porque o django-tenants
    mantém `public` no search_path. Usa os models reais (e não apps.get_model)
    justamente porque consumidores não faz parte do estado deste stream de
    migrations.
    """
    from apps_serv.consumidores.models import VinculoConsumidor

    Cliente = apps.get_model('clientes', 'Cliente')
    schema_name = schema_editor.connection.schema_name

    emails = set(
        VinculoConsumidor.objects
        .filter(schema_name=schema_name)
        .values_list('consumidor__email', flat=True)
    )
    if not emails:
        return

    Cliente.objects.filter(email__in=emails).update(origem='servicemanage')


def desfazer(apps, schema_editor):
    """Reversível de propósito: volta todo mundo pro default da 0007, que é o
    estado exato de antes deste backfill."""
    Cliente = apps.get_model('clientes', 'Cliente')
    Cliente.objects.filter(origem='servicemanage').update(origem='manual')


class Migration(migrations.Migration):

    dependencies = [
        ('clientes', '0007_cliente_origem'),
    ]

    operations = [
        migrations.RunPython(marcar_origem_servicemanage, desfazer),
    ]
