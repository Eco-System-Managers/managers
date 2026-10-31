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


def _dinheiro(valor) -> str:
    """Valor monetário no formato da API: string com duas casas ("12.50")."""
    return str(Decimal(str(valor)).quantize(Decimal('0.01')))


def conferir_total_da_cobranca(
    total_servicos: Decimal,
    desconto: Decimal,
    acrescimo: Decimal,
    pagamentos: list,
    credito_aplicado: Decimal,
) -> Decimal:
    """O total a cobrar e a conferência da soma, iguais nos dois modos de agenda.

    O total é o dos serviços (já depois da troca, se houve) mais o acréscimo
    menos o desconto; o que o cliente entregou — os pagamentos mais o crédito
    da comanda — tem de bater com ele (400 `soma_invalida`). Devolve o total.
    """
    total_esperado = (Decimal(total_servicos) + acrescimo - desconto).quantize(Decimal('0.01'))
    total_pagamentos = sum((Decimal(str(p['valor'])) for p in pagamentos), Decimal('0'))
    total_efetivo = (total_pagamentos + credito_aplicado).quantize(Decimal('0.01'))

    if total_efetivo != total_esperado:
        raise ValidationError({
            'detail': f'A soma dos pagamentos (R$ {total_efetivo}) não bate com o total a cobrar (R$ {total_esperado}).',
            'code': 'soma_invalida',
        })
    return total_esperado


def snapshot_do_servico(servico, preco=None) -> dict:
    """O serviço como o app do cliente guarda no agendamento dele: nome, nicho,
    duração, preço e taxa, congelados, com o dinheiro em string. `preco` é o
    cobrado quando difere do da tabela (o congelado da agenda)."""
    return {
        'nome': servico.nome,
        'nicho': servico.nicho,
        'duracao': servico.duracao,
        'preco': _dinheiro(servico.preco if preco is None else preco),
        'taxa_cancelamento': _dinheiro(servico.calcular_taxa_cancelamento()),
    }


def notificar_cobranca(
    sender,
    origem: str,
    agendamento_id: int,
    valor_total: Decimal,
    acrescimo: Decimal,
    acrescimo_motivo: str,
    servicos: list[dict],
) -> None:
    """Avisa quem acompanha o atendimento de fora do tenant (o app do cliente)
    do que a cobrança decidiu. Roda no fim do `cobrar` dos dois modos, e no
    desfazer da esteira com o acréscimo zerado."""
    from django.db import connection
    from .signals import cobranca_registrada

    cobranca_registrada.send(
        sender=sender,
        schema_name=connection.schema_name,
        agendamento_id=agendamento_id,
        origem=origem,
        valor_total=valor_total,
        acrescimo=acrescimo,
        acrescimo_motivo=acrescimo_motivo,
        servicos=servicos,
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
        kanban_efetivados, agenda_efetivados = pagamentos_efetivados()

        # Na esteira o profissional é opcional: filtrando por colaborador, só
        # entram os atendimentos que foram atribuídos a ele.
        pk_qs = kanban_efetivados.filter(
            atendimento__criado_em__date__gte=data_inicio,
            atendimento__criado_em__date__lte=data_fim,
        ).select_related(
            'atendimento__objeto__cliente',
            'atendimento__servico',
            'atendimento__colaborador__user',
        )
        if colaborador_id is not None:
            pk_qs = pk_qs.filter(atendimento__colaborador_id=colaborador_id)

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
            colaborador = p.atendimento.colaborador
            pagamentos.append({
                'origem': OrigemAtendimento.KANBAN,
                # o avulso não tem cliente: entra pela identificação ("Hilux branca")
                'cliente_nome': p.atendimento.rotulo,
                'servico_nome': p.atendimento.servico.nome,
                'colaborador_nome': colaborador.nome_exibido if colaborador else '',
                'forma': p.forma,
                'valor': str(p.valor),
                'repasse': str(p.repasse),
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
                'colaborador_nome': colaborador.nome_exibido if colaborador else '',
                'forma': p.forma,
                'valor': str(p.valor),
                'repasse': str(p.repasse),
                'data_hora': p.agendamento.data_hora.isoformat(),
            })
            sessoes.add(f'a_{p.agendamento_id}')

        pagamentos.sort(key=lambda x: x['data_hora'], reverse=True)

        total = sum(Decimal(p['valor']) for p in pagamentos) if pagamentos else Decimal('0')
        # o que vai para os parceiros (congelado em cada pagamento) e o que
        # fica para a casa
        repasse = sum(Decimal(p['repasse']) for p in pagamentos) if pagamentos else Decimal('0')
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
                'repasse': str(repasse.quantize(Decimal('0.01'))),
                'casa': str((total - repasse).quantize(Decimal('0.01'))),
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
