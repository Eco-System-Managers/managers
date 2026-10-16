from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('empresa', '0004_remove_empresaconfig_capacidade_diaria_add_horario_capacidade'),
    ]

    operations = [
        migrations.AddField(
            model_name='empresaconfig',
            name='latitude',
            field=models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True),
        ),
        migrations.AddField(
            model_name='empresaconfig',
            name='longitude',
            field=models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True),
        ),
        migrations.AddField(
            model_name='empresaconfig',
            name='logo_url',
            field=models.URLField(blank=True),
        ),
    ]
