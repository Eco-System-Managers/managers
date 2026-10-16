import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('consumidores', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='AgendamentoConsumidor',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('schema_name', models.CharField(max_length=63)),
                ('agendamento_id', models.PositiveIntegerField()),
                ('negocio_nome', models.CharField(max_length=255)),
                ('nicho', models.CharField(blank=True, max_length=50)),
                ('servicos', models.JSONField(default=list)),
                ('profissional_nome', models.CharField(blank=True, max_length=255)),
                ('data_hora', models.DateTimeField()),
                ('duracao_total', models.PositiveIntegerField()),
                ('valor_total', models.DecimalField(decimal_places=2, max_digits=10)),
                ('status', models.CharField(
                    choices=[('agendado', 'Agendado'), ('confirmado', 'Confirmado'), ('concluido', 'Concluído'), ('cancelado', 'Cancelado')],
                    default='agendado',
                    max_length=20,
                )),
                ('checkin_realizado', models.BooleanField(default=False)),
                ('criado_em', models.DateTimeField(auto_now_add=True)),
                ('consumidor', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='agendamentos',
                    to='consumidores.consumidor',
                )),
            ],
            options={
                'verbose_name': 'Agendamento do Consumidor',
                'verbose_name_plural': 'Agendamentos dos Consumidores',
                'ordering': ['-data_hora'],
            },
        ),
    ]
