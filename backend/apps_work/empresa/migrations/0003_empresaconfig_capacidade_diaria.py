from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('empresa', '0002_remove_empresaconfig_area_empresaconfig_nicho'),
    ]

    operations = [
        migrations.AddField(
            model_name='empresaconfig',
            name='capacidade_diaria',
            field=models.PositiveIntegerField(blank=True, null=True),
        ),
    ]
