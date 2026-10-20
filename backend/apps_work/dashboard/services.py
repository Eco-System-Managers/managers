import calendar
from datetime import date, timedelta
from decimal import Decimal

from django.db.models import Sum, Count
from django.db.models.functions import TruncDate
from django.utils import timezone


def _var(atual, anterior) -> int | None:
    if not anterior:
        return None
    return round((atual - anterior) / anterior * 100)


class DashboardService:
    def obter_resumo(self) -> dict:
        from apps_work.kanban.models import PagamentoKanban, AtendimentoKanban
        from apps_work.agenda.models import Pagamento, Agendamento, AgendamentoServico
        from apps_work.clientes.models import Cliente
        from apps_work.empresa.models import EmpresaConfig

        config = EmpresaConfig.objects.first()
        tipo_agenda = config.tipo_agenda if config else 'horario'

        hoje = date.today()
        inicio_mes = hoje.replace(day=1)
        inicio_30d = hoje - timedelta(days=29)

        mes_ant = hoje.month - 1 or 12
        ano_ant = hoje.year if hoje.month > 1 else hoje.year - 1
        inicio_mes_anterior = date(ano_ant, mes_ant, 1)
        fim_mes_anterior = date(ano_ant, mes_ant, calendar.monthrange(ano_ant, mes_ant)[1])

        # ── Faturamento mês atual ───────────────────────────────────
        fat_k = PagamentoKanban.objects.filter(
            criado_em__date__gte=inicio_mes,
        ).aggregate(t=Sum('valor'))['t'] or Decimal('0')

        fat_a = Pagamento.objects.filter(
            criado_em__date__gte=inicio_mes,
        ).aggregate(t=Sum('valor'))['t'] or Decimal('0')

        faturamento_mes = fat_k + fat_a

        # ── Faturamento mês anterior ────────────────────────────────
        fat_k_ant = PagamentoKanban.objects.filter(
            criado_em__date__gte=inicio_mes_anterior,
            criado_em__date__lte=fim_mes_anterior,
        ).aggregate(t=Sum('valor'))['t'] or Decimal('0')

        fat_a_ant = Pagamento.objects.filter(
            criado_em__date__gte=inicio_mes_anterior,
            criado_em__date__lte=fim_mes_anterior,
        ).aggregate(t=Sum('valor'))['t'] or Decimal('0')

        faturamento_anterior = fat_k_ant + fat_a_ant

        # ── Atendimentos mês atual ──────────────────────────────────
        at_k = AtendimentoKanban.objects.filter(
            criado_em__date__gte=inicio_mes, pago=True,
        ).count()

        at_a = Agendamento.objects.filter(
            data_hora__date__gte=inicio_mes, status='concluido',
        ).count()

        atendimentos_mes = at_k + at_a

        # ── Atendimentos mês anterior ───────────────────────────────
        at_k_ant = AtendimentoKanban.objects.filter(
            criado_em__date__gte=inicio_mes_anterior,
            criado_em__date__lte=fim_mes_anterior,
            pago=True,
        ).count()

        at_a_ant = Agendamento.objects.filter(
            data_hora__date__gte=inicio_mes_anterior,
            data_hora__date__lte=fim_mes_anterior,
            status='concluido',
        ).count()

        atendimentos_anterior = at_k_ant + at_a_ant

        # ── Ticket médio ────────────────────────────────────────────
        ticket_medio = (
            (faturamento_mes / atendimentos_mes).quantize(Decimal('0.01'))
            if atendimentos_mes else Decimal('0.00')
        )

        # ── Clientes novos ──────────────────────────────────────────
        clientes_novos_mes = Cliente.objects.filter(
            criado_em__date__gte=inicio_mes,
        ).count()

        clientes_novos_anterior = Cliente.objects.filter(
            criado_em__date__gte=inicio_mes_anterior,
            criado_em__date__lte=fim_mes_anterior,
        ).count()

        # ── Ranking de serviços (mês atual) ────────────────────────
        ks_qs = (
            AtendimentoKanban.objects
            .filter(criado_em__date__gte=inicio_mes)
            .values('servico_id', 'servico__nome')
            .annotate(total=Count('id'))
        )
        as_qs = (
            AgendamentoServico.objects
            .filter(agendamento__data_hora__date__gte=inicio_mes)
            .values('servico_id', 'servico__nome')
            .annotate(total=Count('id'))
        )

        servicos: dict[int, dict] = {}
        for row in ks_qs:
            s = servicos.setdefault(row['servico_id'], {'nome': row['servico__nome'], 'total': 0})
            s['total'] += row['total']
        for row in as_qs:
            s = servicos.setdefault(row['servico_id'], {'nome': row['servico__nome'], 'total': 0})
            s['total'] += row['total']

        ranking_servicos = sorted(servicos.values(), key=lambda x: -x['total'])[:5]

        # ── Próximos agendamentos / atendimentos do dia ─────────────
        agendamentos_hoje = []
        if tipo_agenda == 'kanban':
            kanban_qs = (
                AtendimentoKanban.objects
                .filter(criado_em__date=hoje, pago=False)
                .select_related('objeto__cliente', 'servico', 'etapa')
                .order_by('horario_entrada', 'criado_em')[:10]
            )
            for at in kanban_qs:
                hora = (
                    at.horario_entrada.strftime('%H:%M')
                    if at.horario_entrada
                    else timezone.localtime(at.criado_em).strftime('%H:%M')
                )
                agendamentos_hoje.append({
                    'id': at.id,
                    'cliente_nome': at.objeto.cliente.nome,
                    'servico_nome': at.servico.nome,
                    'hora': hora,
                    'status': 'em_andamento',
                })
        else:
            prox_qs = (
                Agendamento.objects
                .filter(data_hora__date=hoje, status__in=['agendado', 'confirmado'])
                .select_related('cliente')
                .prefetch_related('servicos__servico')
                .order_by('data_hora')[:10]
            )
            for ag in prox_qs:
                primeiro = next(iter(ag.servicos.all()), None)
                agendamentos_hoje.append({
                    'id': ag.id,
                    'cliente_nome': ag.cliente.nome,
                    'servico_nome': primeiro.servico.nome if primeiro else '',
                    # data_hora é UTC no banco; a hora mostrada é a local.
                    'hora': timezone.localtime(ag.data_hora).strftime('%H:%M'),
                    'status': ag.status,
                })

        # ── Série 30 dias ───────────────────────────────────────────
        fat_k_map = dict(
            PagamentoKanban.objects
            .filter(criado_em__date__gte=inicio_30d)
            .annotate(dia=TruncDate('criado_em'))
            .values('dia').annotate(t=Sum('valor'))
            .values_list('dia', 't')
        )
        fat_a_map = dict(
            Pagamento.objects
            .filter(criado_em__date__gte=inicio_30d)
            .annotate(dia=TruncDate('criado_em'))
            .values('dia').annotate(t=Sum('valor'))
            .values_list('dia', 't')
        )
        at_k_map = dict(
            AtendimentoKanban.objects
            .filter(criado_em__date__gte=inicio_30d, pago=True)
            .annotate(dia=TruncDate('criado_em'))
            .values('dia').annotate(t=Count('id'))
            .values_list('dia', 't')
        )
        at_a_map = dict(
            Agendamento.objects
            .filter(data_hora__date__gte=inicio_30d, status='concluido')
            .annotate(dia=TruncDate('data_hora'))
            .values('dia').annotate(t=Count('id'))
            .values_list('dia', 't')
        )

        faturamento_30d = []
        atendimentos_30d = []
        for i in range(30):
            d = inicio_30d + timedelta(days=i)
            fat = (fat_k_map.get(d) or Decimal('0')) + (fat_a_map.get(d) or Decimal('0'))
            at = (at_k_map.get(d) or 0) + (at_a_map.get(d) or 0)
            faturamento_30d.append({'data': d.isoformat(), 'valor': str(fat.quantize(Decimal('0.01')))})
            atendimentos_30d.append({'data': d.isoformat(), 'total': at})

        return {
            'tipo_agenda': tipo_agenda,
            'kpis': {
                'faturamento_mes': str(faturamento_mes.quantize(Decimal('0.01'))),
                'faturamento_variacao': _var(faturamento_mes, faturamento_anterior),
                'atendimentos_mes': atendimentos_mes,
                'atendimentos_variacao': _var(atendimentos_mes, atendimentos_anterior),
                'ticket_medio': str(ticket_medio),
                'clientes_novos_mes': clientes_novos_mes,
                'clientes_novos_variacao': _var(clientes_novos_mes, clientes_novos_anterior),
            },
            'ranking_servicos': ranking_servicos,
            'agendamentos_hoje': agendamentos_hoje,
            'faturamento_30d': faturamento_30d,
            'atendimentos_30d': atendimentos_30d,
        }
