from datetime import datetime, timedelta, date, time
from decimal import Decimal
from django.db import IntegrityError
from rest_framework.exceptions import ValidationError
from .models import AtendimentoKanban, EtapaKanban, PagamentoKanban

ERRO_HORARIO_OCUPADO = {
    'detail': 'Esse horário já foi reservado. Escolha outro.',
    'code': 'horario_ocupado',
}

ERRO_FALTA_EM_PAGO = {
    'detail': 'Esse atendimento já foi cobrado. Desfaça a cobrança antes de marcar falta.',
    'code': 'falta_em_pago',
}

ETAPAS_PADRAO = [
    {'nome': 'Aguardando', 'ordem': 0, 'cor': '#F59E0B'},
    {'nome': 'Em atendimento', 'ordem': 1, 'cor': '#3B82F6'},
    {'nome': 'Concluído', 'ordem': 2, 'cor': '#10B981'},
]

STATUS_AGUARDANDO = 'aguardando'
STATUS_EM_ATENDIMENTO = 'em_atendimento'
STATUS_CONCLUIDO = 'concluido'


class StatusClienteService:
    """Traduz a coluna do quadro no status que o cliente final enxerga no app.

    As etapas são livres — o proprietário cria, renomeia, reordena e apaga —
    então a tradução não pode olhar o nome da coluna. É posicional: a primeira
    é a espera, a última é o fim, e tudo entre as duas é atendimento em
    andamento. Com uma coluna só não existe para onde avançar, então ela conta
    como espera. O quadro padrão (Aguardando / Em atendimento / Concluído) cai
    exatamente nesse desenho.
    """

    def mapa_por_etapa(self) -> dict[int, str]:
        ids = list(EtapaKanban.objects.order_by('ordem').values_list('id', flat=True))
        return {
            etapa_id: self._status_por_posicao(indice, len(ids))
            for indice, etapa_id in enumerate(ids)
        }

    def _status_por_posicao(self, indice: int, total: int) -> str:
        if indice == 0:
            return STATUS_AGUARDANDO
        if indice == total - 1:
            return STATUS_CONCLUIDO
        return STATUS_EM_ATENDIMENTO


class EtapaService:
    def criar_etapas_padrao(self) -> list[EtapaKanban]:
        if EtapaKanban.objects.exists():
            return list(EtapaKanban.objects.all())
        return [EtapaKanban.objects.create(**etapa) for etapa in ETAPAS_PADRAO]

    def reordenar(self, ordem: list[dict]) -> None:
        for item in ordem:
            EtapaKanban.objects.filter(pk=item['id']).update(ordem=item['ordem'])


class AtendimentoKanbanService:
    def criar(
        self,
        etapa: EtapaKanban,
        objeto_id: int,
        servico_id: int,
        observacao: str = '',
        horario_entrada: time | None = None,
        data: date | None = None,
    ) -> AtendimentoKanban:
        from apps_work.clientes.models import ObjetoCliente
        from apps_work.servicos.models import Servico
        objeto = ObjetoCliente.objects.get(pk=objeto_id)
        servico = Servico.objects.get(pk=servico_id)
        data = data or date.today()

        if horario_entrada and AtendimentoKanban.objects.filter(data=data, horario_entrada=horario_entrada).exists():
            raise ValidationError(ERRO_HORARIO_OCUPADO)

        try:
            return AtendimentoKanban.objects.create(
                etapa=etapa,
                objeto=objeto,
                servico=servico,
                observacao=observacao,
                horario_entrada=horario_entrada,
                data=data,
            )
        except IntegrityError:
            # Rede de segurança contra corrida entre a checagem acima e o
            # create — a UniqueConstraint no banco é quem garante de verdade.
            raise ValidationError(ERRO_HORARIO_OCUPADO)

    def mover(self, atendimento: AtendimentoKanban, etapa: EtapaKanban) -> AtendimentoKanban:
        atendimento.etapa = etapa
        atendimento.save(update_fields=['etapa'])
        return atendimento

    def cobrar(
        self,
        atendimento: AtendimentoKanban,
        desconto: Decimal,
        pagamentos: list,
        credito_aplicado: Decimal = Decimal('0'),
        troco_credito: Decimal = Decimal('0'),
    ) -> AtendimentoKanban:
        from apps_work.servicos.models import Servico
        from apps_work.financeiro.services import SaldoService

        servico = Servico.objects.get(pk=atendimento.servico_id)
        total_esperado = (servico.preco - desconto).quantize(Decimal('0.01'))
        total_pagamentos = sum(Decimal(str(p['valor'])) for p in pagamentos).quantize(Decimal('0.01'))
        total_efetivo = (total_pagamentos + credito_aplicado).quantize(Decimal('0.01'))

        if total_efetivo != total_esperado:
            raise ValidationError({
                'detail': f'A soma dos pagamentos (R$ {total_efetivo}) não bate com o total a cobrar (R$ {total_esperado}).',
                'code': 'soma_invalida',
            })

        cliente_id = atendimento.objeto.cliente_id
        saldo_service = SaldoService()

        if credito_aplicado > Decimal('0'):
            saldo_service.aplicar_credito(cliente_id, credito_aplicado, atendimento.pk)

        atendimento.desconto = desconto
        atendimento.pago = True
        atendimento.save(update_fields=['desconto', 'pago'])

        atendimento.pagamentos.all().delete()
        PagamentoKanban.objects.bulk_create([
            PagamentoKanban(atendimento=atendimento, forma=p['forma'], valor=p['valor'])
            for p in pagamentos
        ])

        if troco_credito > Decimal('0'):
            saldo_service.adicionar_troco(cliente_id, troco_credito, atendimento.pk)

        return atendimento

    def desfazer_cobranca(self, atendimento: AtendimentoKanban) -> AtendimentoKanban:
        from apps_work.financeiro.models import TransacaoCredito

        TransacaoCredito.objects.filter(atendimento_kanban=atendimento).delete()
        atendimento.pagamentos.all().delete()
        atendimento.pago = False
        atendimento.desconto = Decimal('0')
        atendimento.save(update_fields=['pago', 'desconto'])
        return atendimento

    def marcar_falta(self, atendimento: AtendimentoKanban) -> AtendimentoKanban:
        """Registra que o cliente não apareceu.

        Recusa atendimento já pago: o dinheiro está no caixa e marcar falta o
        deixaria contabilizado como receita de um serviço que não houve. Quem
        cobrou por engano desfaz a cobrança primeiro.
        """
        if atendimento.pago:
            raise ValidationError(ERRO_FALTA_EM_PAGO)

        atendimento.faltou = True
        atendimento.save(update_fields=['faltou'])
        self._notificar_falta(atendimento)
        return atendimento

    def desfazer_falta(self, atendimento: AtendimentoKanban) -> AtendimentoKanban:
        atendimento.faltou = False
        atendimento.save(update_fields=['faltou'])
        self._notificar_falta(atendimento)
        return atendimento

    def _notificar_falta(self, atendimento: AtendimentoKanban) -> None:
        from django.db import connection
        from .signals import atendimento_kanban_falta_alterada

        atendimento_kanban_falta_alterada.send(
            sender=AtendimentoKanban,
            schema_name=connection.schema_name,
            atendimento_id=atendimento.pk,
            faltou=atendimento.faltou,
        )


class SlotService:
    def gerar_slots(self, data: date) -> list[dict]:
        from apps_work.empresa.models import HorarioFuncionamento

        dia_semana = data.weekday()  # 0=Segunda … 6=Domingo

        try:
            horario = HorarioFuncionamento.objects.get(dia=dia_semana, ativo=True)
        except HorarioFuncionamento.DoesNotExist:
            return []

        if not horario.abertura or not horario.fechamento or not horario.capacidade:
            return []

        abertura_dt = datetime.combine(data, horario.abertura)
        fechamento_dt = datetime.combine(data, horario.fechamento)
        total_minutos = int((fechamento_dt - abertura_dt).total_seconds() // 60)

        if total_minutos <= 0:
            return []

        intervalo = round(total_minutos / horario.capacidade)
        if intervalo < 1:
            return []

        slots: list[time] = []
        atual = abertura_dt
        for _ in range(horario.capacidade):
            if atual >= fechamento_dt:
                break
            slots.append(atual.time().replace(second=0, microsecond=0))
            atual += timedelta(minutes=intervalo)

        ocupados: set[time] = set(
            AtendimentoKanban.objects
            .filter(data=data, horario_entrada__isnull=False)
            .values_list('horario_entrada', flat=True)
        )
        # Normaliza para HH:MM sem segundos
        ocupados = {t.replace(second=0, microsecond=0) for t in ocupados}

        return [
            {'horario': slot.strftime('%H:%M'), 'disponivel': slot not in ocupados}
            for slot in slots
        ]
