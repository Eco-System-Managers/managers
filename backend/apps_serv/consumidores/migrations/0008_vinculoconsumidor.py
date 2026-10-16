from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('consumidores', '0007_remove_agendamentoconsumidor_checkin_realizado'),
    ]

    operations = [
        migrations.CreateModel(
            name='VinculoConsumidor',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('schema_name', models.CharField(max_length=63)),
                ('criado_em', models.DateTimeField(auto_now_add=True)),
                ('consumidor', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='vinculos', to='consumidores.consumidor')),
            ],
            options={
                'verbose_name': 'Vínculo com negócio',
                'verbose_name_plural': 'Vínculos com negócios',
                'unique_together': {('consumidor', 'schema_name')},
            },
        ),
    ]
