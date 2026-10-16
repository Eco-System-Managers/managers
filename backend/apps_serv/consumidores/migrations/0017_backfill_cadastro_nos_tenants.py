import logging

from django.db import migrations

logger = logging.getLogger(__name__)

CAMPOS = ['nome', 'telefone', 'cpf', 'data_nascimento', 'cep', 'endereco', 'numero_endereco']


def espelhar_cadastro_nos_tenants(apps, schema_editor):
    """Acerta as cópias que ficaram para trás.

    Até aqui o Cliente de cada tenant era gravado uma vez, no vínculo, e nunca
    mais atualizado — quem trocou de telefone depois disso deixou o negócio com
    o número velho. Agora que o perfil sincroniza, esta migration faz o mesmo
    para o que já existia.

    Percorre por tenant, e não por consumidor, para trocar de schema uma vez
    por negócio em vez de uma vez por pessoa.
    """
    from django_tenants.utils import schema_context

    Consumidor = apps.get_model('consumidores', 'Consumidor')
    Vinculo = apps.get_model('consumidores', 'VinculoConsumidor')

    schemas = Vinculo.objects.filter(ativo=True).values_list('schema_name', flat=True).distinct()

    for schema_name in schemas:
        consumidores = Consumidor.objects.filter(
            vinculos__schema_name=schema_name, vinculos__ativo=True,
        ).distinct()
        try:
            with schema_context(schema_name):
                Cliente = apps.get_model('clientes', 'Cliente')
                for consumidor in consumidores:
                    cliente = Cliente.objects.filter(email=consumidor.email).first()
                    if cliente is None:
                        continue
                    for campo in CAMPOS:
                        setattr(cliente, campo, getattr(consumidor, campo))
                    cliente.save(update_fields=CAMPOS)
        except Exception:
            # Um tenant indisponível não pode abortar a migration inteira: os
            # demais continuam, e esse se acerta no próximo salvamento do
            # perfil daquele cliente.
            logger.warning(
                'Backfill do cadastro pulou um tenant',
                extra={'schema_name': schema_name},
                exc_info=True,
            )


def nao_reverte(apps, schema_editor):
    """Sem volta: não há registro do que havia antes em cada cópia."""


class Migration(migrations.Migration):

    dependencies = [
        ('consumidores', '0016_consumidor_cep_consumidor_cpf_and_more'),
    ]

    operations = [
        migrations.RunPython(espelhar_cadastro_nos_tenants, nao_reverte),
    ]
