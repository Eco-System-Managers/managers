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
