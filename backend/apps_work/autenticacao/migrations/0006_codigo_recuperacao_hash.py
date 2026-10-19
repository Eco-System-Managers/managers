from django.db import migrations, models


def invalidar_codigos(apps, schema_editor):
    # Os códigos existentes estão em texto puro e não conferem com o hash.
    apps.get_model('autenticacao_work', 'CodigoRecuperacao').objects.update(usado=True)


class Migration(migrations.Migration):

    dependencies = [
        ('autenticacao_work', '0005_drop_ghost_lastactivity'),
    ]

    operations = [
        migrations.RenameField('codigorecuperacao', 'codigo', 'codigo_hash'),
        migrations.AlterField(
            model_name='codigorecuperacao',
            name='codigo_hash',
            field=models.CharField(max_length=128),
        ),
        migrations.AddField(
            model_name='codigorecuperacao',
            name='tentativas',
            field=models.PositiveSmallIntegerField(default=0),
        ),
        migrations.RunPython(invalidar_codigos, migrations.RunPython.noop),
    ]
