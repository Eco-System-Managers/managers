from rest_framework import serializers

from .models import Assinatura, PagamentoAssinatura


class AssinaturaSerializer(serializers.ModelSerializer):
    plano_nome = serializers.CharField(source='plano.get_nome_display', read_only=True)
    bloqueada = serializers.BooleanField(read_only=True)

    class Meta:
        model = Assinatura
        fields = ['status', 'plano_nome', 'inicio', 'proximo_vencimento', 'trial_fim', 'bloqueada']


class PagamentoAssinaturaSerializer(serializers.ModelSerializer):
    class Meta:
        model = PagamentoAssinatura
        fields = ['valor', 'status', 'data']


# ---------------------------------------------------------------------------
# Formatos de entrada e saída (documentação OpenAPI das APIViews)
# ---------------------------------------------------------------------------

class LinkAssinaturaSerializer(serializers.Serializer):
    init_point = serializers.URLField(help_text='Link do checkout do Mercado Pago.')


class ConfirmarAssinaturaSerializer(serializers.Serializer):
    preapproval_id = serializers.CharField()

