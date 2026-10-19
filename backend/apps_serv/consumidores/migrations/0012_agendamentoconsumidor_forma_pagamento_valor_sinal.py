from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('consumidores', '0011_agendamentoconsumidor_objeto_dados'),
    ]

    operations = [
        migrations.AddField(
            model_name='agendamentoconsumidor',
            name='forma_pagamento',
            field=models.CharField(
                choices=[('presencial', 'Pagar na hora'), ('carteira', 'Carteira digital')],
                default='presencial',
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='agendamentoconsumidor',
            name='valor_sinal',
            field=models.DecimalField(decimal_places=2, default=0, max_digits=10),
        ),
    ]
