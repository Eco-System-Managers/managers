from decimal import Decimal

from rest_framework import serializers

from apps_work.agenda.models import FormaPagamento, OrigemAtendimento
from core.excecoes import ErroDeNegocio

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
    repasse = serializers.DecimalField(max_digits=12, decimal_places=2, help_text='A parte dos parceiros, congelada em cada pagamento.')
    casa = serializers.DecimalField(
        max_digits=12, decimal_places=2, allow_null=True,
        help_text='total - repasse. Nulo para o parceiro: ele vê só a parte dele.',
    )


class CaixaPorFormaSerializer(serializers.Serializer):
    forma = serializers.CharField()
    total = serializers.DecimalField(max_digits=12, decimal_places=2)
    percentual = serializers.IntegerField()


class CaixaPagamentoSerializer(serializers.Serializer):
    origem = serializers.ChoiceField(choices=OrigemAtendimento.choices)
    cliente_nome = serializers.CharField()
    servico_nome = serializers.CharField()
    colaborador_nome = serializers.CharField(help_text='Vazio quando o atendimento não tem profissional.')
    forma = serializers.CharField()
    valor = serializers.DecimalField(max_digits=10, decimal_places=2)
    repasse = serializers.DecimalField(max_digits=10, decimal_places=2)
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


# ---------------------------------------------------------------------------
# Cobrança de atendimento (agenda e kanban)
# ---------------------------------------------------------------------------

class PagamentoCobrancaSerializer(serializers.Serializer):
    forma = serializers.ChoiceField(choices=FormaPagamento.choices)
    valor = serializers.DecimalField(max_digits=10, decimal_places=2)


class CobrancaSerializer(serializers.Serializer):
    """Entrada do `cobrar` da agenda e do kanban.

    Antes cada view fazia `Decimal(str(...))` direto no corpo: valor inválido
    virava 500 (InvalidOperation). Aqui vira 400 com o campo apontado.
    """
    desconto = serializers.DecimalField(max_digits=10, decimal_places=2, default=Decimal('0'))
    pagamentos = PagamentoCobrancaSerializer(many=True)
    credito_aplicado = serializers.DecimalField(max_digits=10, decimal_places=2, default=Decimal('0'))
    troco_credito = serializers.DecimalField(max_digits=10, decimal_places=2, default=Decimal('0'))

    def validate_pagamentos(self, valor):
        if not valor:
            raise ErroDeNegocio('Pelo menos uma forma de pagamento é obrigatória.', 'sem_pagamentos')
        return valor

