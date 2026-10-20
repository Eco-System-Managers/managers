from rest_framework import serializers

from apps_work.empresa.models import TipoAgenda


# ---------------------------------------------------------------------------
# Formatos de entrada e saída (documentação OpenAPI das APIViews)
# ---------------------------------------------------------------------------

class DashboardKpisSerializer(serializers.Serializer):
    faturamento_mes = serializers.DecimalField(max_digits=12, decimal_places=2)
    faturamento_variacao = serializers.IntegerField(
        allow_null=True, help_text='Variação % sobre o mês anterior; null sem base de comparação.',
    )
    atendimentos_mes = serializers.IntegerField()
    atendimentos_variacao = serializers.IntegerField(allow_null=True)
    ticket_medio = serializers.DecimalField(max_digits=12, decimal_places=2)
    clientes_novos_mes = serializers.IntegerField()
    clientes_novos_variacao = serializers.IntegerField(allow_null=True)


class RankingServicoSerializer(serializers.Serializer):
    nome = serializers.CharField()
    total = serializers.IntegerField()


class AgendamentoHojeSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    cliente_nome = serializers.CharField()
    servico_nome = serializers.CharField()
    hora = serializers.CharField(help_text='HH:MM')
    status = serializers.CharField()


class FaturamentoDiaSerializer(serializers.Serializer):
    data = serializers.DateField()
    valor = serializers.DecimalField(max_digits=12, decimal_places=2)


class AtendimentosDiaSerializer(serializers.Serializer):
    data = serializers.DateField()
    total = serializers.IntegerField()


class DashboardResumoSerializer(serializers.Serializer):
    tipo_agenda = serializers.ChoiceField(choices=TipoAgenda.choices)
    kpis = DashboardKpisSerializer()
    ranking_servicos = RankingServicoSerializer(many=True, help_text='Top 5 do mês.')
    agendamentos_hoje = AgendamentoHojeSerializer(many=True, help_text='Até 10 do dia.')
    faturamento_30d = FaturamentoDiaSerializer(many=True)
    atendimentos_30d = AtendimentosDiaSerializer(many=True)
