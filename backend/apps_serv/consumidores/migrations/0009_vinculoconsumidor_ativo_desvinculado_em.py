from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('consumidores', '0008_vinculoconsumidor'),
    ]

    operations = [
        migrations.AddField(
            model_name='vinculoconsumidor',
            name='ativo',
            field=models.BooleanField(default=True),
        ),
        migrations.AddField(
            model_name='vinculoconsumidor',
            name='desvinculado_em',
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
