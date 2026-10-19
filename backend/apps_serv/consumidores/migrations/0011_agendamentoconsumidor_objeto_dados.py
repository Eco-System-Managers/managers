from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('consumidores', '0010_objetoconsumidor'),
    ]

    operations = [
        migrations.AddField(
            model_name='agendamentoconsumidor',
            name='objeto_dados',
            field=models.JSONField(blank=True, null=True),
        ),
    ]
