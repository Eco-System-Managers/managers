from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('agenda', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='pagamentoagendamento',
            name='comissao_percentual',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=5, null=True),
        ),
        migrations.AddField(
            model_name='pagamentoagendamento',
            name='repasse',
            field=models.DecimalField(decimal_places=2, default=0, max_digits=8),
        ),
    ]
