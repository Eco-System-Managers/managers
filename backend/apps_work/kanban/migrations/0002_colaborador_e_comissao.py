import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('kanban', '0001_initial'),
        ('usuarios', '0002_colaborador_sem_login_e_vinculo'),
    ]

    operations = [
        migrations.AddField(
            model_name='atendimentokanban',
            name='colaborador',
            field=models.ForeignKey(
                blank=True, null=True, on_delete=django.db.models.deletion.PROTECT,
                related_name='atendimentos_kanban', to='usuarios.colaborador',
            ),
        ),
        migrations.AddField(
            model_name='pagamentoatendimento',
            name='comissao_percentual',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=5, null=True),
        ),
        migrations.AddField(
            model_name='pagamentoatendimento',
            name='repasse',
            field=models.DecimalField(decimal_places=2, default=0, max_digits=8),
        ),
    ]
