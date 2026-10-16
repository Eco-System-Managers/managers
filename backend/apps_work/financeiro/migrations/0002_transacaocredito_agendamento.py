import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('financeiro', '0001_transacao_credito'),
        ('agenda', '0002_agendamento_desconto_pagamento'),
    ]

    operations = [
        migrations.AddField(
            model_name='transacaocredito',
            name='agendamento',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='transacoes_credito',
                to='agenda.agendamento',
            ),
        ),
    ]
