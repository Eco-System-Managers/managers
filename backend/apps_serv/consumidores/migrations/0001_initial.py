import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='Consumidor',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('nome', models.CharField(max_length=255)),
                ('telefone', models.CharField(blank=True, max_length=20)),
                ('foto', models.URLField(blank=True)),
                ('criado_em', models.DateTimeField(auto_now_add=True)),
                ('user', models.OneToOneField(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='consumidor',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={'verbose_name': 'Consumidor', 'verbose_name_plural': 'Consumidores'},
        ),
        migrations.CreateModel(
            name='Carteira',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('saldo', models.DecimalField(decimal_places=2, default=0, max_digits=10)),
                ('atualizado_em', models.DateTimeField(auto_now=True)),
                ('consumidor', models.OneToOneField(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='carteira',
                    to='consumidores.consumidor',
                )),
            ],
            options={'verbose_name': 'Carteira', 'verbose_name_plural': 'Carteiras'},
        ),
    ]
