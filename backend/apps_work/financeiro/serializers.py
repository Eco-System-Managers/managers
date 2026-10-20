from rest_framework import serializers
from .models import Despesa, TransacaoCredito


class TransacaoCreditoSerializer(serializers.ModelSerializer):
    class Meta:
        model = TransacaoCredito
        fields = ['id', 'tipo', 'valor', 'origem', 'descricao', 'atendimento_kanban', 'agendamento', 'criado_em']
        read_only_fields = ['id', 'criado_em']


class DespesaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Despesa
        fields = ['id', 'descricao', 'valor', 'categoria', 'data', 'observacao', 'criado_em']
        read_only_fields = ['id', 'criado_em']

    def validate_valor(self, valor):
        if valor <= 0:
            raise serializers.ValidationError('O valor da despesa deve ser maior que zero.')
        return valor


# ---------------------------------------------------------------------------
# Formatos de entrada e saída (documentação OpenAPI das APIViews)
# ---------------------------------------------------------------------------

class SaldoClienteSerializer(serializers.Serializer):
    saldo = serializers.DecimalField(max_digits=10, decimal_places=2)
    transacoes = TransacaoCreditoSerializer(many=True)


class CaixaKpisSerializer(serializers.Serializer):
    total = serializers.DecimalField(max_digits=12, decimal_places=2)
    ticket_medio = serializers.DecimalField(max_digits=12, decimal_places=2)
    atendimentos = serializers.IntegerField()


class CaixaPorFormaSerializer(serializers.Serializer):
    forma = serializers.CharField()
    total = serializers.DecimalField(max_digits=12, decimal_places=2)
    percentual = serializers.IntegerField()


class CaixaPagamentoSerializer(serializers.Serializer):
    # Mesmos pares de AgendamentoConsumidor.ORIGEM_CHOICES: um enum só no schema.
    origem = serializers.ChoiceField(choices=[('agenda', 'Agenda'), ('kanban', 'Kanban')])
    cliente_nome = serializers.CharField()
    servico_nome = serializers.CharField()
    colaborador_nome = serializers.CharField(help_text='Vazio nos atendimentos do kanban.')
    forma = serializers.CharField()
    valor = serializers.DecimalField(max_digits=10, decimal_places=2)
    data_hora = serializers.DateTimeField()


class CaixaSerializer(serializers.Serializer):
    kpis = CaixaKpisSerializer()
    por_forma = CaixaPorFormaSerializer(many=True)
    pagamentos = CaixaPagamentoSerializer(many=True)


class ResumoCategoriaSerializer(serializers.Serializer):
    categoria = serializers.CharField()
    categoria_label = serializers.CharField()
    total = serializers.DecimalField(max_digits=12, decimal_places=2)
    percentual = serializers.IntegerField()


class ResumoDespesasSerializer(serializers.Serializer):
    total = serializers.DecimalField(max_digits=12, decimal_places=2)
    por_categoria = ResumoCategoriaSerializer(many=True)

