"""Ligacao entre o Consumidor (schema publico) e o Cliente de cada tenant.

Quatro fluxos precisam responder a mesma pergunta — agendar, cancelar com taxa,
vincular e sincronizar o perfil. Cada um resolvia por conta propria, sempre
pelo e-mail, o que espalhava a mesma fragilidade por quatro lugares.
"""

import logging

logger = logging.getLogger(__name__)


def cliente_do_consumidor(consumidor):
    """Acha o Cliente deste consumidor no tenant em que a conexao esta.

    Devolve None quando o negocio ainda nao conhece essa pessoa.

    Procura primeiro por `consumidor_id`, que e a identidade estavel. O e-mail
    fica como reserva para os cadastros anteriores a coluna existir — e, quando
    acha por ele, grava o id. Isso faz o registro se curar no primeiro acesso,
    entao o codigo funciona igual antes e depois do backfill: se a migration
    falhar em algum tenant, aquele tenant continua operando e se acerta sozinho.
    """
    from apps_work.clientes.models import Cliente

    cliente = Cliente.objects.filter(consumidor_id=consumidor.id).first()
    if cliente is not None:
        return cliente

    if not consumidor.email:
        return None

    cliente = Cliente.objects.filter(email=consumidor.email, consumidor_id=None).first()
    if cliente is None:
        return None

    cliente.consumidor_id = consumidor.id
    try:
        cliente.save(update_fields=['consumidor_id'])
    except Exception:
        # `consumidor_id` e unico: se outro Cliente do mesmo tenant ja ficou com
        # este id, gravar aqui falharia. O cadastro encontrado ainda serve para
        # a operacao em curso — quem nao pode quebrar por causa da ligacao e o
        # agendamento.
        logger.warning(
            'Nao foi possivel ligar o cliente ao consumidor',
            extra={'consumidor_id': consumidor.id, 'cliente_id': cliente.pk},
            exc_info=True,
        )

    return cliente
