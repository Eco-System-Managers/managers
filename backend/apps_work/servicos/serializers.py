from decimal import Decimal

from rest_framework import serializers
from apps_work.empresa.models import EmpresaConfig
from apps_work.usuarios.models import Colaborador
from .models import Servico, TipoTaxaCancelamento


class ServicoSerializer(serializers.ModelSerializer):
    colaboradores = serializers.PrimaryKeyRelatedField(
        queryset=Colaborador.objects.filter(ativo=True),
        many=True,
        required=False,
    )

    class Meta:
        model = Servico
        fields = [
            'id', 'nome', 'nicho', 'descricao', 'duracao', 'preco',
            'taxa_cancelamento_tipo', 'taxa_cancelamento_valor',
            'ativo', 'colaboradores',
        ]
        extra_kwargs = {
            'nicho': {
                'required': False,
                'help_text': 'A pasta do serviço: um dos nichos do negócio. Opcional quando o negócio tem um '
                             'nicho só, que é o usado.',
            },
        }

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

        if tipo == TipoTaxaCancelamento.PERCENTUAL and not (Decimal('0') <= valor <= Decimal('30')):
            raise serializers.ValidationError(
                {'taxa_cancelamento_valor': 'O percentual deve estar entre 0 e 30%.'}
            )
        if tipo == TipoTaxaCancelamento.VALOR and preco is not None:
            limite = (preco * Decimal('0.30')).quantize(Decimal('0.01'))
            if valor < 0 or valor > limite:
                raise serializers.ValidationError(
                    {'taxa_cancelamento_valor': f'A taxa fixa não pode ultrapassar 30% do preço (R$ {limite}).'}
                )

        self._resolver_nicho(attrs)
        return attrs

    def _resolver_nicho(self, attrs):
        """O serviço fica num dos nichos do negócio. Com um nicho só, é ele.

        Serviço inativo de um nicho que o negócio deixou pode continuar
        guardado lá; o que não pode é ser reativado ou movido para fora dos
        nichos atuais.
        """
        nichos_do_negocio = EmpresaConfig.objects.filter(pk=1).values_list('nichos', flat=True).first() or []
        nicho = attrs.get('nicho', getattr(self.instance, 'nicho', ''))

        if not nicho:
            if len(nichos_do_negocio) != 1:
                raise serializers.ValidationError({'detail': 'Escolha o nicho do serviço.', 'code': 'nicho_obrigatorio'})
            nicho = attrs['nicho'] = nichos_do_negocio[0]

        ativo = attrs.get('ativo', getattr(self.instance, 'ativo', True))
        if ('nicho' in attrs or ativo) and nicho not in nichos_do_negocio:
            raise serializers.ValidationError({
                'detail': 'Este nicho não está entre os do negócio. Escolha um deles para o serviço.',
                'code': 'nicho_fora_do_negocio',
            })
