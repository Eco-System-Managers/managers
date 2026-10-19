from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('consumidores', '0005_alter_agendamentoconsumidor_duracao_total'),
    ]

    operations = [
        migrations.AlterField(
            model_name='codigorecuperacaoconsumidor',
            name='codigo',
            field=models.CharField(max_length=8),
        ),
    ]
