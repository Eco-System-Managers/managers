from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('autenticacao_work', '0002_lastactivity'),
    ]

    operations = [
        migrations.AlterField(
            model_name='codigorecuperacao',
            name='codigo',
            field=models.CharField(max_length=8),
        ),
    ]
