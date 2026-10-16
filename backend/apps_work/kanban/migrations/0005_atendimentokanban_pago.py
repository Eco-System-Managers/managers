from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('kanban', '0004_atendimentokanban_horario_entrada'),
    ]

    operations = [
        migrations.AddField(
            model_name='atendimentokanban',
            name='pago',
            field=models.BooleanField(default=False),
        ),
    ]
