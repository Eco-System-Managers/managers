from django.db import migrations

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
        ('vitrine', '0003_negociopublico_tipo_agenda_tipo_objeto'),
    ]

    operations = [
        migrations.RunPython(backfill_tipo_agenda, migrations.RunPython.noop),
    ]
