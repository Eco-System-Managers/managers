from django.db import migrations, models

_NICHO_TIPO_AGENDA = {
    'lava_rapido': 'kanban',
    'banho_tosa': 'kanban',
}

_NICHO_TIPO_OBJETO = {
    'lava_rapido': 'veiculo',
    'banho_tosa': 'pet',
}


def backfill_tipo_agenda(apps, schema_editor):
    NegocioPublico = apps.get_model('vitrine', 'NegocioPublico')
    for negocio in NegocioPublico.objects.all():
        negocio.tipo_agenda = _NICHO_TIPO_AGENDA.get(negocio.nicho, 'horario')
        negocio.tipo_objeto = _NICHO_TIPO_OBJETO.get(negocio.nicho)
        negocio.save(update_fields=['tipo_agenda', 'tipo_objeto'])


class Migration(migrations.Migration):

    dependencies = [
        ('vitrine', '0002_negociopublico_cidade'),
    ]

    operations = [
        migrations.AddField(
            model_name='negociopublico',
            name='tipo_agenda',
            field=models.CharField(
                choices=[('horario', 'Por horário'), ('kanban', 'Esteira / Kanban')],
                default='horario',
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='negociopublico',
            name='tipo_objeto',
            field=models.CharField(
                blank=True,
                choices=[('veiculo', 'Veículo'), ('pet', 'Pet')],
                max_length=20,
                null=True,
            ),
        ),
        migrations.RunPython(backfill_tipo_agenda, migrations.RunPython.noop),
    ]
