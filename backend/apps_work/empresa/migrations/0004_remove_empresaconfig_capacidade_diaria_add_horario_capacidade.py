from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('empresa', '0003_empresaconfig_capacidade_diaria'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='empresaconfig',
            name='capacidade_diaria',
        ),
        migrations.AddField(
            model_name='horariofuncionamento',
            name='capacidade',
            field=models.PositiveIntegerField(blank=True, null=True),
        ),
    ]
