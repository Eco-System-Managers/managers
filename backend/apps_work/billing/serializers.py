from rest_framework import serializers

from .models import Assinatura, Pagamento


class AssinaturaSerializer(serializers.ModelSerializer):
    plano_nome = serializers.CharField(source='plano.get_nome_display', read_only=True)
    bloqueada = serializers.BooleanField(read_only=True)

    class Meta:
        model = Assinatura
        fields = ['status', 'plano_nome', 'inicio', 'proximo_vencimento', 'trial_fim', 'bloqueada']


class PagamentoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Pagamento
        fields = ['valor', 'status', 'data']
