from decimal import Decimal

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


def copiar_nomes(apps, schema_editor):
    Colaborador = apps.get_model('usuarios', 'Colaborador')
    for colaborador in Colaborador.objects.select_related('user').filter(nome=''):
        user = colaborador.user
        if user is None:
            continue
        nome = f'{user.first_name} {user.last_name}'.strip() or user.email
        Colaborador.objects.filter(pk=colaborador.pk).update(nome=nome)


class Migration(migrations.Migration):

    dependencies = [
        ('usuarios', '0001_initial'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AlterField(
            model_name='colaborador',
            name='user',
            field=models.OneToOneField(
                blank=True, null=True, on_delete=django.db.models.deletion.CASCADE,
                related_name='colaborador', to=settings.AUTH_USER_MODEL,
            ),
        ),
        migrations.AddField(
            model_name='colaborador',
            name='nome',
            field=models.CharField(blank=True, max_length=150),
        ),
        migrations.AddField(
            model_name='colaborador',
            name='tipo',
            field=models.CharField(
                choices=[('parceiro', 'Parceiro'), ('colaborador', 'Colaborador')],
                default='parceiro', max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='colaborador',
            name='comissao_percentual',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=5, null=True),
        ),
        migrations.AddField(
            model_name='colaborador',
            name='pode_cobrar',
            field=models.BooleanField(default=True),
        ),
        migrations.AddField(
            model_name='convitecolaborador',
            name='colaborador',
            field=models.ForeignKey(
                blank=True, null=True, on_delete=django.db.models.deletion.CASCADE,
                related_name='convites', to='usuarios.colaborador',
            ),
        ),
        migrations.RunPython(copiar_nomes, migrations.RunPython.noop),
    ]
