from rest_framework import serializers

from apps_serv.consumidores.serializers import ConsumidorSerializer


# ---------------------------------------------------------------------------
# Formatos de entrada e saída (documentação OpenAPI das APIViews)
# ---------------------------------------------------------------------------

class LoginConsumidorSerializer(serializers.Serializer):
    email = serializers.EmailField()
    senha = serializers.CharField()


class SessaoConsumidorSerializer(serializers.Serializer):
    """Resposta de cadastro e login do Service Manage."""
    access = serializers.CharField()
    consumidor = ConsumidorSerializer()
    refresh = serializers.CharField(
        required=False, help_text='Só para o app mobile (cabeçalho X-Client-Platform: mobile).',
    )


class RenovacaoConsumidorSerializer(serializers.Serializer):
    """Resposta da renovação: um access novo (e o refresh novo, no mobile)."""
    access = serializers.CharField()
    refresh = serializers.CharField(
        required=False, help_text='Só para o app mobile (cabeçalho X-Client-Platform: mobile).',
    )


class RefreshConsumidorSerializer(serializers.Serializer):
    refresh = serializers.CharField(
        required=False,
        help_text='Só no mobile (X-Client-Platform: mobile); no web o refresh vai no cookie httpOnly.',
    )


class RecuperarSenhaConsumidorSerializer(serializers.Serializer):
    email = serializers.EmailField()


class VerificarCodigoConsumidorSerializer(serializers.Serializer):
    email = serializers.EmailField()
    codigo = serializers.CharField()


class NovaSenhaConsumidorSerializer(serializers.Serializer):
    email = serializers.EmailField()
    codigo = serializers.CharField()
    nova_senha = serializers.CharField()
