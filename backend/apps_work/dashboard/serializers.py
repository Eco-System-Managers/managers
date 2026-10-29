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
    faturamento = serializers.DecimalField(
        max_digits=12, decimal_places=2, allow_null=True,
        help_text='Nulo para o colaborador comum, que não vê valores (idem ticket_medio e repasse).',
    )
    faturamento_variacao = serializers.IntegerField(
        allow_null=True, help_text='Variação % sobre o período anterior; null sem base de comparação.',
    )
    atendimentos = serializers.IntegerField()
    atendimentos_variacao = serializers.IntegerField(allow_null=True)
    ticket_medio = serializers.DecimalField(max_digits=12, decimal_places=2, allow_null=True)
    repasse = serializers.DecimalField(
        max_digits=12, decimal_places=2, allow_null=True,
        help_text='A parte dos parceiros no período (congelada em cada pagamento). Para o parceiro, o que ele tem a receber.',
    )
    clientes_novos = serializers.IntegerField(
        allow_null=True, help_text='Null quando filtrado por profissional: cliente novo é do negócio.',
    )
    clientes_novos_variacao = serializers.IntegerField(allow_null=True)


class RankingServicoSerializer(serializers.Serializer):
    nome = serializers.CharField()
    nicho = serializers.CharField(help_text='O nicho do serviço (slug); a tela o indica quando o negócio tem mais de um.')
    total = serializers.IntegerField()


class PontoDaSerieSerializer(serializers.Serializer):
    data = serializers.DateField()
    faturamento = serializers.DecimalField(
        max_digits=12, decimal_places=2, allow_null=True, help_text='Nulo para quem não vê valores.',
    )
    atendimentos = serializers.IntegerField()


class AgendamentoHojeSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    cliente_nome = serializers.CharField()
    cliente_telefone = serializers.CharField(help_text='Só dígitos; para o WhatsApp.')
    servico_nome = serializers.CharField()
    colaborador_nome = serializers.CharField(help_text='Vazio sem profissional.')
    hora = serializers.CharField(help_text='HH:MM')
    status = serializers.CharField()


class DashboardResumoSerializer(serializers.Serializer):
    tipo_agenda = serializers.ChoiceField(choices=TipoAgenda.choices)
    periodo = PeriodoDashboardSerializer()
    colaborador = serializers.IntegerField(
        allow_null=True, help_text='O profissional aplicado (o próprio, para quem não é proprietário).',
    )
    kpis = DashboardKpisSerializer()
    serie = PontoDaSerieSerializer(many=True, help_text='Um ponto por dia do período, com os critérios dos kpis.')
    ranking_servicos = RankingServicoSerializer(many=True, help_text='Top 5 do período.')
    agendamentos_hoje = AgendamentoHojeSerializer(many=True, help_text='Até 10 do dia, independente do período.')
