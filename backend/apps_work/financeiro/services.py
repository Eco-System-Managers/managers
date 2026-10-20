from decimal import Decimal
from datetime import date
from django.db.models import Q, Sum
from rest_framework.exceptions import ValidationError

from apps_work.agenda.models import OrigemAtendimento, StatusAgendamento

from .models import CategoriaDespesa, Despesa, OrigemTransacao, TipoTransacao, TransacaoCredito


class SaldoService:
    def saldo(self, cliente_id: int) -> Decimal:
        result = TransacaoCredito.objects.filter(cliente_id=cliente_id).aggregate(
            total_credito=Sum('valor', filter=Q(tipo=TipoTransacao.CREDITO)),
            total_debito=Sum('valor', filter=Q(tipo=TipoTransacao.DEBITO)),
        )
        credito = result['total_credito'] or Decimal('0')
        debito = result['total_debito'] or Decimal('0')
        return (credito - debito).quantize(Decimal('0.01'))

    def adicionar_troco(
        self,
        cliente_id: int,
        valor: Decimal,
        atendimento_kanban_id: int | None = None,
        agendamento_id: int | None = None,
    ) -> TransacaoCredito:
        return TransacaoCredito.objects.create(
            cliente_id=cliente_id,
            tipo=TipoTransacao.CREDITO,
            valor=valor,
            origem=OrigemTransacao.TROCO,
            atendimento_kanban_id=atendimento_kanban_id,
            agendamento_id=agendamento_id,
            descricao='Troco mantido na comanda',
        )

    def aplicar_credito(
        self,
        cliente_id: int,
        valor: Decimal,
        atendimento_kanban_id: int | None = None,
        agendamento_id: int | None = None,
    ) -> TransacaoCredito:
        valor = valor.quantize(Decimal('0.01'))
        saldo_atual = self.saldo(cliente_id)
        if valor > saldo_atual:
            raise ValidationError({
                'detail': f'Saldo insuficiente. Disponível: R$ {saldo_atual}',
                'code': 'saldo_insuficiente',
            })
        return TransacaoCredito.objects.create(
            cliente_id=cliente_id,
            tipo=TipoTransacao.DEBITO,
            valor=valor,
            origem=OrigemTransacao.DESCONTO_APLICADO,
            atendimento_kanban_id=atendimento_kanban_id,
            agendamento_id=agendamento_id,
            descricao='Saldo aplicado como desconto',
        )

    def registrar_taxa_cancelamento(self, cliente_id: int, valor: Decimal, descricao: str = '') -> TransacaoCredito:
        return TransacaoCredito.objects.create(
            cliente_id=cliente_id,
            tipo=TipoTransacao.DEBITO,
            valor=valor.quantize(Decimal('0.01')),
            origem=OrigemTransacao.TAXA_CANCELAMENTO,
            descricao=descricao,
        )


def pagamentos_efetivados():
    """Pagamentos que contam como receita, nos dois modos de agenda.

    Kanban: atendimento pago. Agenda: agendamento concluído. Fora disso, o
    pagamento é provisório — a vitrine cria um assim que o cliente agenda pelo
    app — e não pode entrar no faturamento. Caixa e dashboard leem daqui para
    não divergirem.
    """
    from apps_work.agenda.models import PagamentoAgendamento
    from apps_work.kanban.models import PagamentoAtendimento
    return (
        PagamentoAtendimento.objects.filter(atendimento__pago=True),
        PagamentoAgendamento.objects.filter(agendamento__status=StatusAgendamento.CONCLUIDO),
    )


class CaixaService:
    def obter_dados(self, data_inicio: date, data_fim: date, colaborador_id: int | None = None) -> dict:
        from apps_work.kanban.models import PagamentoAtendimento

        kanban_efetivados, agenda_efetivados = pagamentos_efetivados()

        # Atendimentos do Kanban não têm colaborador vinculado — filtrar por
        # colaborador exclui esses registros por completo.
        if colaborador_id is None:
            pk_qs = kanban_efetivados.filter(
                atendimento__criado_em__date__gte=data_inicio,
                atendimento__criado_em__date__lte=data_fim,
            ).select_related(
                'atendimento__objeto__cliente',
                'atendimento__servico',
            )
        else:
            pk_qs = PagamentoAtendimento.objects.none()

        pa_qs = agenda_efetivados.filter(
            agendamento__data_hora__date__gte=data_inicio,
            agendamento__data_hora__date__lte=data_fim,
        ).select_related('agendamento__cliente', 'agendamento__colaborador__user').prefetch_related(
            'agendamento__servicos__servico',
        )
        if colaborador_id is not None:
            pa_qs = pa_qs.filter(agendamento__colaborador_id=colaborador_id)

        pagamentos = []
        sessoes: set[str] = set()

        for p in pk_qs:
            pagamentos.append({
                'origem': OrigemAtendimento.KANBAN,
                'cliente_nome': p.atendimento.objeto.cliente.nome,
                'servico_nome': p.atendimento.servico.nome,
                'colaborador_nome': '',
                'forma': p.forma,
                'valor': str(p.valor),
                'data_hora': p.atendimento.criado_em.isoformat(),
            })
            sessoes.add(f'k_{p.atendimento_id}')

        for p in pa_qs:
            primeiro = next(iter(p.agendamento.servicos.all()), None)
            servico_nome = primeiro.servico.nome if primeiro else ''
            colaborador = p.agendamento.colaborador
            pagamentos.append({
                'origem': OrigemAtendimento.AGENDA,
                'cliente_nome': p.agendamento.cliente.nome,
                'servico_nome': servico_nome,
                'colaborador_nome': colaborador.user.get_full_name() if colaborador else '',
                'forma': p.forma,
                'valor': str(p.valor),
                'data_hora': p.agendamento.data_hora.isoformat(),
            })
            sessoes.add(f'a_{p.agendamento_id}')

        pagamentos.sort(key=lambda x: x['data_hora'], reverse=True)

        total = sum(Decimal(p['valor']) for p in pagamentos) if pagamentos else Decimal('0')
        total_sessoes = len(sessoes)
        ticket_medio = (total / total_sessoes).quantize(Decimal('0.01')) if total_sessoes else Decimal('0.00')

        forma_totais: dict[str, Decimal] = {}
        for p in pagamentos:
            forma_totais[p['forma']] = forma_totais.get(p['forma'], Decimal('0')) + Decimal(p['valor'])

        por_forma = [
            {
                'forma': forma,
                'total': str(subtotal.quantize(Decimal('0.01'))),
                'percentual': int(subtotal / total * 100) if total else 0,
            }
            for forma, subtotal in sorted(forma_totais.items(), key=lambda x: -x[1])
        ]

        return {
            'kpis': {
                'total': str(total.quantize(Decimal('0.01'))),
                'ticket_medio': str(ticket_medio),
                'atendimentos': total_sessoes,
            },
            'por_forma': por_forma,
            'pagamentos': pagamentos,
        }


class DespesaService:
    _LABELS = dict(CategoriaDespesa.choices)

    def resumo(self, data_inicio: date, data_fim: date) -> dict:
        linhas = (
            Despesa.objects.filter(data__gte=data_inicio, data__lte=data_fim)
            .values('categoria')
            .annotate(total=Sum('valor'))
        )

        totais = {linha['categoria']: (linha['total'] or Decimal('0')) for linha in linhas}
        total_geral = sum(totais.values(), Decimal('0'))

        por_categoria = [
            {
                'categoria': categoria,
                'categoria_label': self._LABELS.get(categoria, categoria),
                'total': str(subtotal.quantize(Decimal('0.01'))),
                'percentual': int(subtotal / total_geral * 100) if total_geral else 0,
            }
            for categoria, subtotal in sorted(totais.items(), key=lambda item: -item[1])
        ]

        return {
            'total': str(total_geral.quantize(Decimal('0.01'))),
            'por_categoria': por_categoria,
        }
