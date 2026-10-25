from django.db import connection
from django.db.models import ProtectedError

from core.excecoes import ErroDeNegocio

from .models import Cliente, OrigemCliente
from .signals import cliente_servicemanage_removido


class RemocaoClienteService:
    """Remover um cliente do painel significa coisas diferentes conforme a
    origem do cadastro.

    Cadastro feito pelo próprio negócio é apagado de verdade. Já o que veio do
    Service Manage pertence ao consumidor: apagar a linha quebraria a retenção
    do histórico e, pior, o vínculo continuaria ativo no schema público — o
    negócio seguiria em "Seus negócios" e o cliente voltaria à lista no próximo
    agendamento. Nesse caso o registro é arquivado e o vínculo é desfeito.
    """

    def remover(self, cliente: Cliente) -> None:
        if cliente.origem != OrigemCliente.SERVICEMANAGE:
            # Agendamento e atendimento protegem o cliente (PROTECT): o
            # histórico não pode ficar órfão. O Django checa antes de apagar
            # qualquer linha, então a transação segue íntegra.
            try:
                cliente.delete()
            except ProtectedError:
                raise ErroDeNegocio(
                    'Este cliente tem atendimentos registrados e não pode ser removido.',
                    'cliente_com_atendimentos',
                )
            return

        # Mesma regra do desvínculo feito pelo app: os dados pessoais saem.
        cliente.visivel = False
        cliente.save(update_fields=['visivel', *cliente.apagar_dados_pessoais()])

        cliente_servicemanage_removido.send(
            sender=Cliente,
            schema_name=connection.schema_name,
            consumidor_id=cliente.consumidor_id,
        )
