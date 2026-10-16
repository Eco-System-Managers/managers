from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('kanban', '0003_atendimentokanban_servico'),
    ]

    operations = [
        migrations.AddField(
            model_name='atendimentokanban',
            name='horario_entrada',
            field=models.TimeField(blank=True, null=True),
        ),
    ]
