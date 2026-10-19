from django.db import migrations, models


def invalidar_codigos(apps, schema_editor):
    # Os códigos existentes estão em texto puro e não conferem com o hash.
    apps.get_model('consumidores', 'CodigoRecuperacaoConsumidor').objects.update(usado=True)


class Migration(migrations.Migration):

    dependencies = [
        ('consumidores', '0019_sessoes_e_refresh_revogado'),
    ]

    operations = [
        migrations.RenameField('codigorecuperacaoconsumidor', 'codigo', 'codigo_hash'),
        migrations.AlterField(
            model_name='codigorecuperacaoconsumidor',
            name='codigo_hash',
            field=models.CharField(max_length=128),
        ),
        migrations.RunPython(invalidar_codigos, migrations.RunPython.noop),
    ]
