from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    atomic = False

    dependencies = [
        ('consumidores', '0002_agendamentoconsumidor'),
    ]

    operations = [
        # 1. Limpa dados existentes (dev only — auth antiga é incompatível)
        migrations.RunSQL('DELETE FROM consumidores_agendamentoconsumidor;', migrations.RunSQL.noop),
        migrations.RunSQL('DELETE FROM consumidores_carteira;', migrations.RunSQL.noop),
        migrations.RunSQL('DELETE FROM consumidores_consumidor;', migrations.RunSQL.noop),

        # 2. Remove FK para auth_user
        migrations.RemoveField(model_name='consumidor', name='user'),

        # 3. Adiciona campos de autenticação própria
        migrations.AddField(
            model_name='consumidor',
            name='email',
            field=models.EmailField(default='', unique=True),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='consumidor',
            name='password',
            field=models.CharField(default='', max_length=128),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='consumidor',
            name='is_active',
            field=models.BooleanField(default=True),
        ),

        # 4. Cria tabela de códigos de recuperação própria
        migrations.CreateModel(
            name='CodigoRecuperacaoConsumidor',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('codigo', models.CharField(max_length=4)),
                ('criado_em', models.DateTimeField(auto_now_add=True)),
                ('expira_em', models.DateTimeField()),
                ('usado', models.BooleanField(default=False)),
                ('consumidor', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='codigos_recuperacao',
                    to='consumidores.consumidor',
                )),
            ],
            options={
                'verbose_name': 'Código de Recuperação',
                'verbose_name_plural': 'Códigos de Recuperação',
                'ordering': ['-criado_em'],
            },
        ),
    ]
