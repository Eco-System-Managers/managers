from django.conf import settings
from rest_framework import serializers

from .models import Assinatura, PagamentoAssinatura, TipoPlano


class AssinaturaSerializer(serializers.ModelSerializer):
    plano = serializers.CharField(
        source='plano_vigente', read_only=True,
        help_text='pro, business ou enterprise: o que vale agora (o teste é business, o vitalício é enterprise).',
    )
    plano_nome = serializers.SerializerMethodField()
    bloqueada = serializers.BooleanField(read_only=True)
    vitalicia = serializers.BooleanField(read_only=True)
    limite_equipe = serializers.IntegerField(
        source='limite_da_equipe', read_only=True,
        help_text='Quantas pessoas cabem na equipe, sem contar o dono.',
    )
    equipe_ativa = serializers.SerializerMethodField(
        help_text='Quantas pessoas estão ativas na equipe agora, sem contar o dono.',
    )
    checkout_aberto = serializers.SerializerMethodField(
        help_text='False enquanto assinar pelo app não está liberado: o app não mostra a venda.',
    )

    class Meta:
        model = Assinatura
        fields = [
            'status', 'plano', 'plano_nome', 'inicio', 'proximo_vencimento', 'trial_fim', 'bloqueada', 'vitalicia',
            'limite_equipe', 'equipe_ativa', 'checkout_aberto',
        ]

    def get_plano_nome(self, obj) -> str:
        return TipoPlano(obj.plano_vigente).label

    def get_equipe_ativa(self, obj) -> int:
        from apps_work.usuarios.services import ColaboradorService
        return ColaboradorService().equipe_ativa()

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

