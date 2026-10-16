from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('consumidores', '0003_refactor_consumidor_auth_propria'),
    ]

    operations = [
        migrations.AddField(
            model_name='codigorecuperacaoconsumidor',
            name='tentativas',
            field=models.PositiveSmallIntegerField(default=0),
        ),
    ]
