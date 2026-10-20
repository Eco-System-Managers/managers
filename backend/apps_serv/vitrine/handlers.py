import logging

from django.utils import timezone

from apps_work.agenda.signals import agendamento_status_alterado
from apps_work.clientes.signals import cliente_servicemanage_removido
from apps_work.empresa.signals import empresa_config_atualizada
from apps_work.kanban.signals import atendimento_kanban_falta_alterada
from apps_work.agenda.models import OrigemAtendimento, StatusAgendamento

logger = logging.getLogger(__name__)


def _on_empresa_config_atualizada(sender, schema_name, instance, **kwargs):
    # Sem capturar: quem emite (ConfiguracaoEmpresaService.publicar) roda num
    # savepoint e registra a falha — engolir aqui escondia o erro e, sem
    # savepoint, deixaria a transação abortada.
    from .services import SincronizarVitrineService
    SincronizarVitrineService().sincronizar(schema_name, instance)


def _on_cliente_servicemanage_removido(sender, schema_name, email, **kwargs):
    """O negócio removeu do painel um cliente que veio do app: desfaz o vínculo
    para o negócio sair de "Seus negócios" e o cadastro não ressurgir na lista
    no próximo agendamento."""
    from apps_serv.consumidores.models import VinculoConsumidor

    try:
        VinculoConsumidor.objects.filter(
            schema_name=schema_name,
            consumidor__email=email,
            ativo=True,
        ).update(ativo=False, desvinculado_em=timezone.now())
    except Exception:
        logger.warning(
            'Falha ao desfazer vínculo do consumidor removido pelo painel',
            extra={'schema_name': schema_name},
            exc_info=True,
        )


def _on_agendamento_status_alterado(sender, schema_name, agendamento_id, status, **kwargs):
    """Espelha no schema público o status que o negócio definiu no painel.

    Só alcança agendamento nascido no app (origem 'agenda'); o criado no balcão
    não tem contraparte e o filtro simplesmente não encontra nada. Esteira fica
    de fora porque o status dela é lido ao vivo da coluna do quadro.
    """
    from apps_serv.consumidores.models import AgendamentoConsumidor

    try:
        AgendamentoConsumidor.objects.filter(
            schema_name=schema_name,
            agendamento_id=agendamento_id,
            origem=OrigemAtendimento.AGENDA,
        ).update(status=status)
    except Exception:
        logger.warning(
            'Falha ao espelhar status do agendamento no schema público',
            extra={'schema_name': schema_name, 'agendamento_id': agendamento_id},
            exc_info=True,
        )


def _on_atendimento_kanban_falta_alterada(sender, schema_name, atendimento_id, faltou, **kwargs):
    """Espelha a falta da esteira no schema público.

    O status da esteira normalmente é lido ao vivo da coluna do quadro, mas
    falta não é coluna — sem empurrar aqui, o cliente continuaria vendo o
    atendimento como em andamento. Ao desfazer, volta pra 'agendado': o ponto
    exato do quadro volta a ser lido ao vivo, como nos demais.
    """
    from apps_serv.consumidores.models import AgendamentoConsumidor

    try:
        AgendamentoConsumidor.objects.filter(
            schema_name=schema_name,
            agendamento_id=atendimento_id,
            origem=OrigemAtendimento.KANBAN,
        ).update(status=StatusAgendamento.FALTOU if faltou else StatusAgendamento.AGENDADO)
    except Exception:
        logger.warning(
            'Falha ao espelhar falta do atendimento no schema público',
            extra={'schema_name': schema_name, 'atendimento_id': atendimento_id},
            exc_info=True,
        )


empresa_config_atualizada.connect(_on_empresa_config_atualizada)
cliente_servicemanage_removido.connect(_on_cliente_servicemanage_removido)
agendamento_status_alterado.connect(_on_agendamento_status_alterado)
atendimento_kanban_falta_alterada.connect(_on_atendimento_kanban_falta_alterada)
