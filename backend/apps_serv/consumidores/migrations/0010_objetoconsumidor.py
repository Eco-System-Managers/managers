from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('consumidores', '0009_vinculoconsumidor_ativo_desvinculado_em'),
    ]

    operations = [
        migrations.CreateModel(
            name='ObjetoConsumidor',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('tipo', models.CharField(choices=[('veiculo', 'Veículo'), ('pet', 'Pet')], max_length=20)),
                ('dados', models.JSONField()),
                ('nome_exibicao', models.CharField(max_length=255)),
                ('criado_em', models.DateTimeField(auto_now_add=True)),
                ('consumidor', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='objetos',
                    to='consumidores.consumidor',
                )),
            ],
            options={
                'verbose_name': 'Objeto do Consumidor',
                'verbose_name_plural': 'Objetos dos Consumidores',
                'ordering': ['-criado_em'],
            },
        ),
    ]
