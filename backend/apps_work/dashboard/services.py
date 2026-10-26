from dataclasses import dataclass
from datetime import date, timedelta
from decimal import Decimal

from django.db.models import Count, Sum
from django.utils import timezone

from apps_work.agenda.models import StatusAgendamento
from apps_work.empresa.models import TipoAgenda
from apps_work.financeiro.services import pagamentos_efetivados


def _var(atual, anterior) -> int | None:
    if not anterior:
        return None
    return round((atual - anterior) / anterior * 100)


@dataclass(frozen=True)
class Periodo:
    inicio: date
    fim: date

    @property
    def dias(self) -> int:
        return (self.fim - self.inicio).days + 1

    # O período de comparação tem o mesmo tamanho e termina na véspera: hoje
    # compara com ontem, uma semana com a semana anterior.
    @property
    def anterior(self) -> 'Periodo':
        return Periodo(self.inicio - timedelta(days=self.dias), self.inicio - timedelta(days=1))


class DashboardService:
    """Os números de um período, comparados com o período anterior.

    Receita e atendimentos seguem a definição do caixa (`pagamentos_efetivados`
    e a data do atendimento), para o painel nunca divergir do fechamento.
    Com `colaborador_id`, só a agenda daquele profissional entra: a esteira não
    tem colaborador e fica de fora, como no caixa.
    """

    def obter_resumo(
        self,
        data_inicio: date | None = None,
        data_fim: date | None = None,
        colaborador_id: int | None = None,
    ) -> dict:
        from apps_work.empresa.models import EmpresaConfig

        config = EmpresaConfig.objects.first()
        tipo_agenda = config.tipo_agenda if config else TipoAgenda.HORARIO

        hoje = timezone.localdate()
        periodo = Periodo(data_inicio or hoje, data_fim or hoje)
        anterior = periodo.anterior

        atual = self._numeros(periodo, colaborador_id)
        passado = self._numeros(anterior, colaborador_id)

        ticket_medio = (
            (atual['faturamento'] / atual['atendimentos']).quantize(Decimal('0.01'))
            if atual['atendimentos'] else Decimal('0.00')
        )

        return {
            'tipo_agenda': tipo_agenda,
            'periodo': {
                'data_inicio': periodo.inicio.isoformat(),
                'data_fim': periodo.fim.isoformat(),
                'anterior_inicio': anterior.inicio.isoformat(),
                'anterior_fim': anterior.fim.isoformat(),
            },
            'colaborador': colaborador_id,
            'kpis': {
                'faturamento': str(atual['faturamento'].quantize(Decimal('0.01'))),
                'faturamento_variacao': _var(atual['faturamento'], passado['faturamento']),
                'atendimentos': atual['atendimentos'],
                'atendimentos_variacao': _var(atual['atendimentos'], passado['atendimentos']),
                'ticket_medio': str(ticket_medio),
                'clientes_novos': atual['clientes_novos'],
                'clientes_novos_variacao': (
                    _var(atual['clientes_novos'], passado['clientes_novos'])
                    if atual['clientes_novos'] is not None else None
                ),
            },
            'ranking_servicos': self._ranking(periodo, colaborador_id),
            'agendamentos_hoje': self._hoje(tipo_agenda, hoje, colaborador_id),
        }

    def _numeros(self, periodo: Periodo, colaborador_id: int | None) -> dict:
        from apps_work.agenda.models import Agendamento
        from apps_work.clientes.models import Cliente
        from apps_work.kanban.models import AtendimentoKanban

        kanban_efetivados, agenda_efetivados = pagamentos_efetivados()
        intervalo = (periodo.inicio, periodo.fim)

        agenda_pagos = agenda_efetivados.filter(agendamento__data_hora__date__range=intervalo)
        agenda_concluidos = Agendamento.objects.filter(
            data_hora__date__range=intervalo, status=StatusAgendamento.CONCLUIDO,
        )
        if colaborador_id is not None:
            agenda_pagos = agenda_pagos.filter(agendamento__colaborador_id=colaborador_id)
            agenda_concluidos = agenda_concluidos.filter(colaborador_id=colaborador_id)

        faturamento = agenda_pagos.aggregate(t=Sum('valor'))['t'] or Decimal('0')
        atendimentos = agenda_concluidos.count()

        if colaborador_id is None:
            faturamento += (
                kanban_efetivados
                .filter(atendimento__criado_em__date__range=intervalo)
                .aggregate(t=Sum('valor'))['t'] or Decimal('0')
            )
            atendimentos += AtendimentoKanban.objects.filter(
                criado_em__date__range=intervalo, pago=True,
            ).count()

        # Cliente novo é do negócio, não de um profissional: filtrado, não há
        # como atribuir, e o número sai nulo em vez de enganar.
        clientes_novos = (
            Cliente.objects.filter(criado_em__date__range=intervalo).count()
            if colaborador_id is None else None
        )

        return {
            'faturamento': faturamento,
            'atendimentos': atendimentos,
            'clientes_novos': clientes_novos,
        }

    def _ranking(self, periodo: Periodo, colaborador_id: int | None) -> list[dict]:
        from apps_work.agenda.models import AgendamentoServico
        from apps_work.kanban.models import AtendimentoKanban

        intervalo = (periodo.inicio, periodo.fim)
        servicos: dict[int, dict] = {}

        def somar(linhas):
            for row in linhas:
                s = servicos.setdefault(row['servico_id'], {'nome': row['servico__nome'], 'total': 0})
                s['total'] += row['total']

        agenda = AgendamentoServico.objects.filter(agendamento__data_hora__date__range=intervalo)
        if colaborador_id is not None:
            agenda = agenda.filter(agendamento__colaborador_id=colaborador_id)
        somar(agenda.values('servico_id', 'servico__nome').annotate(total=Count('id')))

        if colaborador_id is None:
            somar(
                AtendimentoKanban.objects
                .filter(criado_em__date__range=intervalo)
                .values('servico_id', 'servico__nome')
                .annotate(total=Count('id'))
            )

        return sorted(servicos.values(), key=lambda x: -x['total'])[:5]

    # Os próximos do dia: independe do período escolhido, é o que vem agora.
    def _hoje(self, tipo_agenda: str, hoje: date, colaborador_id: int | None) -> list[dict]:
        from apps_work.agenda.models import Agendamento
        from apps_work.kanban.models import AtendimentoKanban

        if tipo_agenda == TipoAgenda.KANBAN:
            if colaborador_id is not None:
                return []
            kanban_qs = (
                AtendimentoKanban.objects
                .filter(criado_em__date=hoje, pago=False)
                .select_related('objeto__cliente', 'servico', 'etapa')
                .order_by('horario_entrada', 'criado_em')[:10]
            )
            return [
                {
                    'id': at.id,
                    'cliente_nome': at.objeto.cliente.nome,
                    'servico_nome': at.servico.nome,
                    'hora': (
                        at.horario_entrada.strftime('%H:%M')
                        if at.horario_entrada
                        else timezone.localtime(at.criado_em).strftime('%H:%M')
                    ),
                    'status': 'em_andamento',
                }
                for at in kanban_qs
            ]

        prox_qs = (
            Agendamento.objects
            .filter(
                data_hora__date=hoje,
                status__in=[StatusAgendamento.AGENDADO, StatusAgendamento.CONFIRMADO],
            )
            .select_related('cliente')
            .prefetch_related('servicos__servico')
            .order_by('data_hora')
        )
        if colaborador_id is not None:
            prox_qs = prox_qs.filter(colaborador_id=colaborador_id)
        resultado = []
        for ag in prox_qs[:10]:
            primeiro = next(iter(ag.servicos.all()), None)
            resultado.append({
                'id': ag.id,
                'cliente_nome': ag.cliente.nome,
                'servico_nome': primeiro.servico.nome if primeiro else '',
                # data_hora é UTC no banco; a hora mostrada é a local.
                'hora': timezone.localtime(ag.data_hora).strftime('%H:%M'),
                'status': ag.status,
            })
        return resultado
