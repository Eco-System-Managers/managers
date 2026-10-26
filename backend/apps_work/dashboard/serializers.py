from rest_framework import serializers

from apps_work.empresa.models import TipoAgenda


# ---------------------------------------------------------------------------
# Formatos de entrada e saída (documentação OpenAPI das APIViews)
# ---------------------------------------------------------------------------

class PeriodoDashboardSerializer(serializers.Serializer):
    data_inicio = serializers.DateField()
    data_fim = serializers.DateField()
    anterior_inicio = serializers.DateField(help_text='O período de comparação: mesmo tamanho, termina na véspera.')
    anterior_fim = serializers.DateField()


class DashboardKpisSerializer(serializers.Serializer):
    faturamento = serializers.DecimalField(max_digits=12, decimal_places=2)
    faturamento_variacao = serializers.IntegerField(
        allow_null=True, help_text='Variação % sobre o período anterior; null sem base de comparação.',
    )
    atendimentos = serializers.IntegerField()
    atendimentos_variacao = serializers.IntegerField(allow_null=True)
    ticket_medio = serializers.DecimalField(max_digits=12, decimal_places=2)
    clientes_novos = serializers.IntegerField(
        allow_null=True, help_text='Null quando filtrado por profissional: cliente novo é do negócio.',
    )
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


class DashboardResumoSerializer(serializers.Serializer):
    tipo_agenda = serializers.ChoiceField(choices=TipoAgenda.choices)
    periodo = PeriodoDashboardSerializer()
    colaborador = serializers.IntegerField(
        allow_null=True, help_text='O profissional aplicado (o próprio, para quem não é proprietário).',
    )
    kpis = DashboardKpisSerializer()
    ranking_servicos = RankingServicoSerializer(many=True, help_text='Top 5 do período.')
    agendamentos_hoje = AgendamentoHojeSerializer(many=True, help_text='Até 10 do dia, independente do período.')
