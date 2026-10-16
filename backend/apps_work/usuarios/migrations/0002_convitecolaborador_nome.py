from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('usuarios', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='convitecolaborador',
            name='nome',
            field=models.CharField(blank=True, default='', max_length=150),
        ),
    ]
