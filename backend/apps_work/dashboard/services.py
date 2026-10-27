from dataclasses import dataclass
from datetime import date, timedelta
from decimal import Decimal

from django.db.models import Count, Sum
from django.db.models.functions import TruncDate
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
    Com `colaborador_id`, só o que é daquele profissional entra, nos dois
    modos (na esteira, os atendimentos atribuídos a ele), como no caixa.
    `com_valores=False` (colaborador comum) zera os kpis de dinheiro.
    """

    def obter_resumo(
        self,
        data_inicio: date | None = None,
        data_fim: date | None = None,
        colaborador_id: int | None = None,
        com_valores: bool = True,
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

        # o colaborador comum não vê dinheiro: os kpis de valor saem nulos
        def valor(x):
            return x if com_valores else None

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
                'faturamento': valor(str(atual['faturamento'].quantize(Decimal('0.01')))),
                'faturamento_variacao': valor(_var(atual['faturamento'], passado['faturamento'])),
                'atendimentos': atual['atendimentos'],
                'atendimentos_variacao': _var(atual['atendimentos'], passado['atendimentos']),
                'ticket_medio': valor(str(ticket_medio)),
                'repasse': valor(str(atual['repasse'].quantize(Decimal('0.01')))),
                'clientes_novos': atual['clientes_novos'],
                'clientes_novos_variacao': (
                    _var(atual['clientes_novos'], passado['clientes_novos'])
                    if atual['clientes_novos'] is not None else None
                ),
            },
            'serie': [
                {**ponto, 'faturamento': valor(ponto['faturamento'])}
                for ponto in self._serie(periodo, colaborador_id)
            ],
            'ranking_servicos': self._ranking(periodo, colaborador_id),
            'agendamentos_hoje': self._hoje(tipo_agenda, hoje, colaborador_id),
        }

    # Um ponto por dia do período, com os mesmos critérios de `_numeros`:
    # é o gráfico do painel. Dias sem nada saem zerados, para a barra existir.
    def _serie(self, periodo: Periodo, colaborador_id: int | None) -> list[dict]:
        from apps_work.agenda.models import Agendamento
        from apps_work.kanban.models import AtendimentoKanban

        kanban_efetivados, agenda_efetivados = pagamentos_efetivados()
        intervalo = (periodo.inicio, periodo.fim)

        agenda_pagos = agenda_efetivados.filter(agendamento__data_hora__date__range=intervalo)
        agenda_concluidos = Agendamento.objects.filter(
            data_hora__date__range=intervalo, status=StatusAgendamento.CONCLUIDO,
        )
        kanban_pagos = kanban_efetivados.filter(atendimento__criado_em__date__range=intervalo)
        kanban_concluidos = AtendimentoKanban.objects.filter(criado_em__date__range=intervalo, pago=True)
        if colaborador_id is not None:
            agenda_pagos = agenda_pagos.filter(agendamento__colaborador_id=colaborador_id)
            agenda_concluidos = agenda_concluidos.filter(colaborador_id=colaborador_id)
            kanban_pagos = kanban_pagos.filter(atendimento__colaborador_id=colaborador_id)
            kanban_concluidos = kanban_concluidos.filter(colaborador_id=colaborador_id)

        faturamento: dict[date, Decimal] = {}
        atendimentos: dict[date, int] = {}

        def somar(linhas, alvo):
            for row in linhas:
                alvo[row['dia']] = alvo.get(row['dia'], 0) + row['total']

        somar(agenda_pagos.values(dia=TruncDate('agendamento__data_hora')).annotate(total=Sum('valor')), faturamento)
        somar(kanban_pagos.values(dia=TruncDate('atendimento__criado_em')).annotate(total=Sum('valor')), faturamento)
        somar(agenda_concluidos.values(dia=TruncDate('data_hora')).annotate(total=Count('id')), atendimentos)
        somar(kanban_concluidos.values(dia=TruncDate('criado_em')).annotate(total=Count('id')), atendimentos)

        return [
            {
                'data': dia.isoformat(),
                'faturamento': str(Decimal(faturamento.get(dia, 0)).quantize(Decimal('0.01'))),
                'atendimentos': atendimentos.get(dia, 0),
            }
            for dia in (periodo.inicio + timedelta(days=i) for i in range(periodo.dias))
        ]

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

        somas = agenda_pagos.aggregate(t=Sum('valor'), r=Sum('repasse'))
        faturamento = somas['t'] or Decimal('0')
        repasse = somas['r'] or Decimal('0')
        atendimentos = agenda_concluidos.count()

        # na esteira o profissional é opcional: filtrando, só o que foi
        # atribuído a ele entra
        kanban_pagos = kanban_efetivados.filter(atendimento__criado_em__date__range=intervalo)
        kanban_concluidos = AtendimentoKanban.objects.filter(criado_em__date__range=intervalo, pago=True)
        if colaborador_id is not None:
            kanban_pagos = kanban_pagos.filter(atendimento__colaborador_id=colaborador_id)
            kanban_concluidos = kanban_concluidos.filter(colaborador_id=colaborador_id)
        somas = kanban_pagos.aggregate(t=Sum('valor'), r=Sum('repasse'))
        faturamento += somas['t'] or Decimal('0')
        repasse += somas['r'] or Decimal('0')
        atendimentos += kanban_concluidos.count()

        # Cliente novo é do negócio, não de um profissional: filtrado, não há
        # como atribuir, e o número sai nulo em vez de enganar.
        clientes_novos = (
            Cliente.objects.filter(criado_em__date__range=intervalo).count()
            if colaborador_id is None else None
        )

        return {
            'faturamento': faturamento,
            'repasse': repasse,
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

        kanban = AtendimentoKanban.objects.filter(criado_em__date__range=intervalo)
        if colaborador_id is not None:
            kanban = kanban.filter(colaborador_id=colaborador_id)
        somar(kanban.values('servico_id', 'servico__nome').annotate(total=Count('id')))

        return sorted(servicos.values(), key=lambda x: -x['total'])[:5]

    # Os próximos do dia: independe do período escolhido, é o que vem agora.
    def _hoje(self, tipo_agenda: str, hoje: date, colaborador_id: int | None) -> list[dict]:
        from apps_work.agenda.models import Agendamento
        from apps_work.kanban.models import AtendimentoKanban

        if tipo_agenda == TipoAgenda.KANBAN:
            kanban_qs = (
                AtendimentoKanban.objects
                .filter(criado_em__date=hoje, pago=False)
                .select_related('objeto__cliente', 'servico', 'etapa', 'colaborador__user')
                .order_by('horario_entrada', 'criado_em')
            )
            if colaborador_id is not None:
                kanban_qs = kanban_qs.filter(colaborador_id=colaborador_id)
            kanban_qs = kanban_qs[:10]
            return [
                {
                    'id': at.id,
                    'cliente_nome': at.objeto.cliente.nome,
                    'cliente_telefone': at.objeto.cliente.telefone,
                    'servico_nome': at.servico.nome,
                    'colaborador_nome': at.colaborador.nome_exibido if at.colaborador_id else '',
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
            .select_related('cliente', 'colaborador__user')
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
                'cliente_telefone': ag.cliente.telefone,
                'servico_nome': primeiro.servico.nome if primeiro else '',
                'colaborador_nome': ag.colaborador.nome_exibido if ag.colaborador_id else '',
                # data_hora é UTC no banco; a hora mostrada é a local.
                'hora': timezone.localtime(ag.data_hora).strftime('%H:%M'),
                'status': ag.status,
            })
        return resultado
