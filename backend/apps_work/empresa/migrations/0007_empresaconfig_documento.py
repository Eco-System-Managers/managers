import re

from django.db import migrations, models


def cnpj_para_documento(apps, schema_editor):
    """Todo cnpj já preenchido vira documento com tipo 'cnpj'. Só os dígitos —
    o campo antigo aceitava a máscara (00.000.000/0000-00)."""
    EmpresaConfig = apps.get_model('empresa', 'EmpresaConfig')
    for config in EmpresaConfig.objects.exclude(cnpj='').iterator():
        digitos = re.sub(r'\D', '', config.cnpj)
        if len(digitos) != 14:
            continue
        config.documento = digitos
        config.tipo_documento = 'cnpj'
        config.save(update_fields=['documento', 'tipo_documento'])


def documento_para_cnpj(apps, schema_editor):
    EmpresaConfig = apps.get_model('empresa', 'EmpresaConfig')
    for config in EmpresaConfig.objects.filter(tipo_documento='cnpj').iterator():
        config.cnpj = config.documento
        config.save(update_fields=['cnpj'])


class Migration(migrations.Migration):

    dependencies = [
        ('empresa', '0006_empresaconfig_cidade_endereco'),
    ]

    operations = [
        migrations.AddField(
            model_name='empresaconfig',
            name='documento',
            field=models.CharField(blank=True, max_length=14),
        ),
        migrations.AddField(
            model_name='empresaconfig',
            name='tipo_documento',
            field=models.CharField(
                blank=True,
                choices=[('cpf', 'CPF'), ('cnpj', 'CNPJ')],
                max_length=4,
            ),
        ),
        migrations.RunPython(cnpj_para_documento, documento_para_cnpj),
        migrations.RemoveField(
            model_name='empresaconfig',
            name='cnpj',
        ),
    ]
