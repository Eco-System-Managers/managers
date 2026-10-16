from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('consumidores', '0006_alter_codigorecuperacaoconsumidor_codigo'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='agendamentoconsumidor',
            name='checkin_realizado',
        ),
    ]
