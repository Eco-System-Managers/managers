from drf_spectacular.utils import extend_schema_serializer
from rest_framework import serializers

from .models import Assinatura, Pagamento


class AssinaturaSerializer(serializers.ModelSerializer):
    plano_nome = serializers.CharField(source='plano.get_nome_display', read_only=True)
    bloqueada = serializers.BooleanField(read_only=True)

    class Meta:
        model = Assinatura
        fields = ['status', 'plano_nome', 'inicio', 'proximo_vencimento', 'trial_fim', 'bloqueada']


@extend_schema_serializer(component_name='PagamentoAssinatura')
class PagamentoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Pagamento
        fields = ['valor', 'status', 'data']


# ---------------------------------------------------------------------------
# Formatos de entrada e saída (documentação OpenAPI das APIViews)
# ---------------------------------------------------------------------------

class LinkAssinaturaSerializer(serializers.Serializer):
    init_point = serializers.URLField(help_text='Link do checkout do Mercado Pago.')


class ConfirmarAssinaturaSerializer(serializers.Serializer):
    preapproval_id = serializers.CharField()

