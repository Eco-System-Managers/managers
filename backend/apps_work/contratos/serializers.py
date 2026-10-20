from rest_framework import serializers

from .models import Contrato, ModeloContrato


class ModeloContratoSerializer(serializers.ModelSerializer):
    class Meta:
        model = ModeloContrato
        fields = ['id', 'titulo', 'corpo', 'ativo', 'criado_em', 'atualizado_em']
        read_only_fields = ['criado_em', 'atualizado_em']


class ContratoSerializer(serializers.ModelSerializer):
    cliente_nome = serializers.CharField(source='cliente.nome', read_only=True)
    cliente_email = serializers.CharField(source='cliente.email', read_only=True)

    class Meta:
        model = Contrato
        fields = [
            'id', 'modelo', 'cliente', 'cliente_nome', 'cliente_email',
            'titulo', 'corpo', 'status', 'token',
            'nome_assinante', 'ip_assinante', 'assinado_em',
            'criado_em', 'atualizado_em',
        ]
        read_only_fields = [
            'token', 'status', 'nome_assinante', 'ip_assinante',
            'assinado_em', 'criado_em', 'atualizado_em',
        ]


class GerarContratoSerializer(serializers.Serializer):
    modelo_id = serializers.IntegerField()
    cliente_id = serializers.IntegerField()


class AssinarContratoSerializer(serializers.Serializer):
    nome_assinante = serializers.CharField(max_length=255)


class ContratoPublicoSerializer(serializers.ModelSerializer):
    """Serializer para o endpoint público — expõe apenas o necessário para assinatura."""
    negocio_nome = serializers.SerializerMethodField()

    class Meta:
        model = Contrato
        fields = ['titulo', 'corpo', 'status', 'negocio_nome', 'assinado_em']

    def get_negocio_nome(self, obj) -> str:
        try:
            from apps_work.empresa.models import EmpresaConfig
            config = EmpresaConfig.objects.first()
            return config.nome if config else ''
        except Exception:
            return ''


# ---------------------------------------------------------------------------
# Formatos de entrada e saída (documentação OpenAPI das APIViews)
# ---------------------------------------------------------------------------

class AcaoContratoPublicoSerializer(serializers.Serializer):
    acao = serializers.ChoiceField(choices=['assinar', 'recusar'])
    nome_assinante = serializers.CharField(required=False, help_text='Obrigatório quando acao=assinar.')

