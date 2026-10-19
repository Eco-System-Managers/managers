from decimal import Decimal

from rest_framework import serializers
from apps_work.usuarios.models import Colaborador
from .models import Servico


class ServicoSerializer(serializers.ModelSerializer):
    colaboradores = serializers.PrimaryKeyRelatedField(
        queryset=Colaborador.objects.filter(ativo=True),
        many=True,
        required=False,
    )

    class Meta:
        model = Servico
        fields = [
            'id', 'nome', 'descricao', 'duracao', 'preco',
            'taxa_cancelamento_tipo', 'taxa_cancelamento_valor',
            'ativo', 'colaboradores',
        ]

    def to_representation(self, instance):
        rep = super().to_representation(instance)
        rep['colaboradores'] = list(
            Colaborador.objects.filter(servicos=instance, ativo=True).values_list('id', flat=True)
        )
        return rep

    def validate_preco(self, value):
        if value <= 0:
            raise serializers.ValidationError('O preço deve ser maior que zero.')
        return value

    def validate_duracao(self, value):
        if value <= 0:
            raise serializers.ValidationError('A duração deve ser maior que zero.')
        if value > 360:
            raise serializers.ValidationError('A duração máxima permitida é de 6 horas (360 minutos).')
        return value

    def validate(self, attrs):
        tipo = attrs.get('taxa_cancelamento_tipo', getattr(self.instance, 'taxa_cancelamento_tipo', ''))
        valor = attrs.get('taxa_cancelamento_valor', getattr(self.instance, 'taxa_cancelamento_valor', Decimal('0')))
        preco = attrs.get('preco', getattr(self.instance, 'preco', None))

        if tipo == 'percentual' and not (Decimal('0') <= valor <= Decimal('30')):
            raise serializers.ValidationError(
                {'taxa_cancelamento_valor': 'O percentual deve estar entre 0 e 30%.'}
            )
        if tipo == 'valor' and preco is not None:
            limite = (preco * Decimal('0.30')).quantize(Decimal('0.01'))
            if valor < 0 or valor > limite:
                raise serializers.ValidationError(
                    {'taxa_cancelamento_valor': f'A taxa fixa não pode ultrapassar 30% do preço (R$ {limite}).'}
                )
        return attrs
