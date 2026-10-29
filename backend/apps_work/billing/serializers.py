from django.conf import settings
from rest_framework import serializers

from .models import Assinatura, PagamentoAssinatura


class AssinaturaSerializer(serializers.ModelSerializer):
    plano_nome = serializers.CharField(source='plano.get_nome_display', read_only=True)
    bloqueada = serializers.BooleanField(read_only=True)
    checkout_aberto = serializers.SerializerMethodField(
        help_text='False enquanto assinar pelo app não está liberado: o app mostra "Em breve".',
    )

    class Meta:
        model = Assinatura
        fields = ['status', 'plano_nome', 'inicio', 'proximo_vencimento', 'trial_fim', 'bloqueada', 'checkout_aberto']

    def get_checkout_aberto(self, obj) -> bool:
        return settings.ASSINATURA_ABERTA


class PagamentoAssinaturaSerializer(serializers.ModelSerializer):
    class Meta:
        model = PagamentoAssinatura
        fields = ['valor', 'status', 'data']


# ---------------------------------------------------------------------------
# Formatos de entrada e saída (documentação OpenAPI das APIViews)
# ---------------------------------------------------------------------------

class LinkAssinaturaSerializer(serializers.Serializer):
    link_checkout = serializers.URLField(help_text='Link do checkout hospedado pelo gateway de pagamento.')


class ConfirmarAssinaturaSerializer(serializers.Serializer):
    id_externo = serializers.CharField(
        help_text='Id da assinatura no gateway, recebido no retorno do checkout '
                  '(no Mercado Pago, o parâmetro preapproval_id).',
    )

