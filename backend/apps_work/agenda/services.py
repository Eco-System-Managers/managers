from datetime import date, datetime, timedelta
from decimal import Decimal
from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError
from .models import Agendamento, OrigemAtendimento, PagamentoAgendamento, StatusAgendamento

DURACAO_PADRAO_MINUTOS = 30

ERRO_HORARIO_CONFLITO = {
    'detail': 'Esse colaborador já tem um agendamento nesse horário.',
    'code': 'horario_conflito',
}


class DiasComRegistroService:
    """Datas de um mês que já têm atendimento marcado, somando os dois modos de
    agenda. A interface usa isso para não esconder um dia fechado que tenha
    registro — sem essa checagem, mudar o horário de funcionamento tornaria
    invisível o que já estava agendado naquele dia da semana."""

    def listar(self, ano: int, mes: int) -> list[str]:
        from apps_work.kanban.models import AtendimentoKanban

        datas = set(
            Agendamento.objects
            .filter(data_hora__year=ano, data_hora__month=mes)
            .exclude(status=StatusAgendamento.CANCELADO)
            .values_list('data_hora__date', flat=True)
        )
        datas.update(
            AtendimentoKanban.objects
            .filter(data__year=ano, data__month=mes, data__isnull=False)
            .values_list('data', flat=True)
        )
        return sorted(d.isoformat() for d in datas)


class PendenciasCobrancaService:
    """Atendimentos que já passaram da data e nunca foram cobrados.

    A agenda mostra um dia por vez e o caixa é montado a partir das linhas de
    PagamentoAgendamento: sem essa lista, o que ficou para trás não aparece em lugar
    nenhum, e o faturamento fica menor do que o que de fato entrou.

    Junta as duas origens como o CaixaService faz — quem consome não precisa
    saber se o negócio usa agenda por horário ou esteira.
    """

    def listar(self, hoje: date | None = None) -> list[dict]:
        from apps_work.kanban.models import AtendimentoKanban

        hoje = hoje or timezone.localdate()
        pendencias = []

        agendamentos = (
            Agendamento.objects
            .filter(data_hora__date__lt=hoje, status__in=[StatusAgendamento.AGENDADO, StatusAgendamento.CONFIRMADO])
            .select_related('cliente')
            .prefetch_related('servicos__servico')
        )
        for ag in agendamentos:
            servicos = list(ag.servicos.all())
            pendencias.append({
                'origem': OrigemAtendimento.AGENDA,
                'id': ag.pk,
                'data': ag.data_hora.astimezone().date().isoformat(),
                'cliente_id': ag.cliente_id,
                'cliente_nome': ag.cliente.nome,
                'servico_nome': ' + '.join(s.servico.nome for s in servicos) or '—',
                'valor': str(sum((s.preco_cobrado for s in servicos), Decimal('0')) - ag.desconto),
                # No formato que o CobrancaModal consome, pra cobrar direto da
                # lista sem precisar abrir a agenda naquele dia.
                'servicos': [
                    {'servico_id': s.servico_id, 'nome': s.servico.nome, 'preco': str(s.preco_cobrado)}
                    for s in servicos
                ],
            })

        atendimentos = (
            AtendimentoKanban.objects
            .filter(data__lt=hoje, pago=False, faltou=False, data__isnull=False)
            .select_related('objeto__cliente', 'servico')
        )
        for at in atendimentos:
            pendencias.append({
                'origem': OrigemAtendimento.KANBAN,
                'id': at.pk,
                'data': at.data.isoformat(),
                'cliente_id': at.objeto.cliente_id,
                'cliente_nome': at.objeto.cliente.nome,
                'servico_nome': at.servico.nome,
                'valor': str(at.servico.preco - at.desconto),
                'servicos': [
                    {'servico_id': at.servico_id, 'nome': at.servico.nome, 'preco': str(at.servico.preco)}
                ],
            })

        # Mais antigo primeiro: é o que está há mais tempo fora do caixa.
        pendencias.sort(key=lambda p: p['data'])
        return pendencias


class SlotsAgendaService:
    """Grade de horários de um colaborador num dia, como o quadro da esteira.

    A agenda por horário sempre foi escolha às cegas: o usuário digitava a hora
    e só descobria o choque ao salvar. Aqui a ocupação vira grade, no mesmo
    formato do SlotService do kanban, para o app poder reaproveitar a tela.

    A agenda é individual — a grade olha só os agendamentos daquele colaborador,
    e a ocupação de um não interfere na do outro.
    """

    # o passo da grade, igual ao da agenda do app
    INTERVALO_MINUTOS = 15

    def listar(self, data: date, servico_id: int, colaborador_id: int) -> list[dict]:
        """Os horários livres do dia para este serviço com este profissional.

        Candidatos: a grade de 15 em 15 minutos a partir da abertura e, além
        dela, o fim de cada agendamento já marcado — acabou um às 9:20, o 9:20
        é oferecido, sem esperar o 9:30. Só os que cabem inteiros (o serviço
        todo antes do fechamento, sem bater em ninguém) entram; a grade da
        agenda já mostra o que está ocupado, então os ocupados não vêm.
        """
        from apps_work.empresa.models import HorarioFuncionamento
        from apps_work.servicos.models import Servico

        horario = HorarioFuncionamento.objects.filter(dia=data.weekday(), ativo=True).first()
        if not horario or not horario.abertura or not horario.fechamento:
            return []

        servico = Servico.objects.filter(pk=servico_id, ativo=True).first()
        if not servico:
            return []

        abertura = datetime.combine(data, horario.abertura)
        fechamento = datetime.combine(data, horario.fechamento)
        duracao = timedelta(minutes=servico.duracao or DURACAO_PADRAO_MINUTOS)

        ocupados = self._intervalos_ocupados(data, colaborador_id)

        candidatos = set()
        atual = abertura
        while atual + duracao <= fechamento:
            candidatos.add(atual)
            atual += timedelta(minutes=self.INTERVALO_MINUTOS)
        for _, fim_oc in ocupados:
            if abertura <= fim_oc and fim_oc + duracao <= fechamento:
                candidatos.add(fim_oc)

        return [
            {'horario': inicio.strftime('%H:%M'), 'disponivel': True}
            for inicio in sorted(candidatos)
            if all(inicio + duracao <= inicio_oc or inicio >= fim_oc for inicio_oc, fim_oc in ocupados)
        ]

    def _intervalos_ocupados(self, data: date, colaborador_id: int) -> list[tuple]:
        agendamentos = (
            Agendamento.objects
            .filter(
                data_hora__date=data,
                colaborador_id=colaborador_id,
                status__in=[StatusAgendamento.AGENDADO, StatusAgendamento.CONFIRMADO],
            )
            .prefetch_related('servicos__servico')
        )
        intervalos = []
        for ag in agendamentos:
            duracao = sum(s.servico.duracao for s in ag.servicos.all()) or DURACAO_PADRAO_MINUTOS
            inicio = ag.data_hora.astimezone().replace(tzinfo=None)
            intervalos.append((inicio, inicio + timedelta(minutes=duracao)))
        return intervalos


class AgendamentoService:
    def notificar_mudanca_de_status(self, agendamento: Agendamento, status_anterior: str) -> None:
        """Avisa quem acompanha o agendamento de fora do tenant. Só dispara na
        mudança real — salvar o agendamento sem mexer no status não é evento."""
        if agendamento.status == status_anterior:
            return

        from django.db import connection
        from .signals import agendamento_status_alterado

        agendamento_status_alterado.send(
            sender=Agendamento,
            schema_name=connection.schema_name,
            agendamento_id=agendamento.pk,
            status=agendamento.status,
        )

    def verificar_conflito_para_criacao(self, colaborador, data_hora: datetime, servico_id: int | None) -> None:
        duracao = None
        if servico_id:
            from apps_work.servicos.models import Servico
            servico = Servico.objects.filter(pk=servico_id).first()
            duracao = servico.duracao if servico else None
        self._verificar_conflito(colaborador, data_hora, duracao)

    def verificar_conflito_para_atualizacao(self, agendamento: Agendamento, colaborador, data_hora: datetime) -> None:
        duracao = sum(s.servico.duracao for s in agendamento.servicos.all()) or None
        self._verificar_conflito(colaborador, data_hora, duracao, excluir_id=agendamento.pk)

    def _verificar_conflito(self, colaborador, data_hora: datetime, duracao_minutos: int | None, excluir_id: int | None = None) -> None:
        if colaborador is None:
            return

        duracao = duracao_minutos or DURACAO_PADRAO_MINUTOS
        inicio = data_hora
        fim = data_hora + timedelta(minutes=duracao)

        candidatos = (
            Agendamento.objects
            .filter(colaborador=colaborador, data_hora__date=data_hora.date())
            .exclude(status=StatusAgendamento.CANCELADO)
            .prefetch_related('servicos__servico')
        )
        if excluir_id:
            candidatos = candidatos.exclude(pk=excluir_id)

        for outro in candidatos:
            outro_duracao = sum(s.servico.duracao for s in outro.servicos.all()) or DURACAO_PADRAO_MINUTOS
            outro_inicio = outro.data_hora
            outro_fim = outro_inicio + timedelta(minutes=outro_duracao)
            if inicio < outro_fim and outro_inicio < fim:
                raise ValidationError(ERRO_HORARIO_CONFLITO)

    @transaction.atomic
    def cobrar(
        self,
        agendamento: Agendamento,
        desconto: Decimal,
        pagamentos: list,
        credito_aplicado: Decimal = Decimal('0'),
        troco_credito: Decimal = Decimal('0'),
    ) -> Agendamento:
        from apps_work.financeiro.services import SaldoService

        total_servicos = sum(s.preco_cobrado for s in agendamento.servicos.all())
        total_esperado = (total_servicos - desconto).quantize(Decimal('0.01'))
        total_pagamentos = sum(Decimal(str(p['valor'])) for p in pagamentos).quantize(Decimal('0.01'))
        total_efetivo = (total_pagamentos + credito_aplicado).quantize(Decimal('0.01'))

        if total_efetivo != total_esperado:
            raise ValidationError({
                'detail': f'A soma dos pagamentos (R$ {total_efetivo}) não bate com o total a cobrar (R$ {total_esperado}).',
                'code': 'soma_invalida',
            })

        saldo_service = SaldoService()

        if credito_aplicado > Decimal('0'):
            saldo_service.aplicar_credito(agendamento.cliente_id, credito_aplicado, agendamento_id=agendamento.pk)

        status_anterior = agendamento.status
        agendamento.desconto = desconto
        agendamento.status = StatusAgendamento.CONCLUIDO
        agendamento.save(update_fields=['desconto', 'status'])
        self.notificar_mudanca_de_status(agendamento, status_anterior)

        # a comissão do parceiro congela aqui: mudar o acordo depois não
        # reescreve o que já foi cobrado
        colaborador = agendamento.colaborador
        agendamento.pagamentos.all().delete()
        PagamentoAgendamento.objects.bulk_create([
            PagamentoAgendamento(
                agendamento=agendamento, forma=p['forma'], valor=p['valor'],
                comissao_percentual=colaborador.comissao_percentual if colaborador and colaborador.eh_parceiro else None,
                repasse=colaborador.comissao_para(p['valor']) if colaborador else Decimal('0.00'),
            )
            for p in pagamentos
        ])

        if troco_credito > Decimal('0'):
            saldo_service.adicionar_troco(agendamento.cliente_id, troco_credito, agendamento_id=agendamento.pk)

        return agendamento
