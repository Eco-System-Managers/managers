"""Identidade estavel entre o Cliente do tenant e o Consumidor do publico.

Ate aqui o par era encontrado por e-mail, o que prendia a ligacao a um dado que
a pessoa pode querer trocar — e por isso a edicao do e-mail estava bloqueada no
app.

O backfill vive nesta migration, e nao numa do app compartilhado, justamente
porque ela roda dentro de cada schema de tenant: o `search_path` ja e
`tenant,public`, entao o Consumidor esta ao alcance e a ordem entre criar a
coluna e preenche-la se resolve sozinha.
"""

import logging

from django.db import migrations, models

logger = logging.getLogger(__name__)


def ligar_pelo_email(apps, schema_editor):
    """Preenche consumidor_id nos cadastros que ja existem.

    E a ultima vez que o e-mail e usado como chave. Dai em diante ele volta a
    ser so um dado de contato.

    Liga apenas o primeiro Cliente de cada e-mail: `email` nao e unico no
    Cliente, entao um tenant pode ter dois cadastros com o mesmo endereco. E o
    mesmo criterio que o codigo ja aplicava com `.first()`.
    """
    schema_name = getattr(schema_editor.connection, 'schema_name', None)
    if schema_name in (None, 'public'):
        # Os apps de tenant tambem sao criados no schema publico, onde nao ha
        # cliente de negocio nenhum para ligar.
        return

    Cliente = apps.get_model('clientes', 'Cliente')
    Consumidor = apps.get_model('consumidores', 'Consumidor')

    # So os clientes que vieram do app tem consumidor do outro lado; cadastro
    # feito na mao pelo negocio continua com consumidor_id nulo, corretamente.
    candidatos = Cliente.objects.filter(origem='servicemanage').exclude(email='')
    emails = list(candidatos.values_list('email', flat=True))
    if not emails:
        return

    por_email = dict(
        Consumidor.objects.filter(email__in=emails).values_list('email', 'id')
    )

    ligados = 0
    vistos = set()
    for cliente in candidatos.order_by('id'):
        consumidor_id = por_email.get(cliente.email)
        if consumidor_id is None or consumidor_id in vistos:
            continue
        vistos.add(consumidor_id)
        cliente.consumidor_id = consumidor_id
        cliente.save(update_fields=['consumidor_id'])
        ligados += 1

    if ligados:
        logger.info(
            'Backfill de consumidor_id concluido',
            extra={'schema_name': schema_name, 'ligados': ligados},
        )


def desligar(apps, schema_editor):
    """A volta e possivel: o e-mail continua no Cliente, entao a ligacao pode
    ser refeita. Basta limpar a coluna antes de ela ser removida."""
    Cliente = apps.get_model('clientes', 'Cliente')
    Cliente.objects.exclude(consumidor_id=None).update(consumidor_id=None)


class Migration(migrations.Migration):

    dependencies = [
        ('clientes', '0010_cliente_foto_chave'),
        # Declarada para o `apps.get_model('consumidores', ...)` do backfill
        # encontrar o modelo no estado da migration. `consumidores` e app
        # compartilhada e migra antes dos tenants, entao a ordem se sustenta.
        ('consumidores', '0018_remove_consumidor_foto_consumidor_foto_chave'),
    ]

    operations = [
        migrations.AddField(
            model_name='cliente',
            name='consumidor_id',
            field=models.PositiveIntegerField(blank=True, db_index=True, null=True, unique=True),
        ),
        migrations.RunPython(ligar_pelo_email, desligar),
    ]
