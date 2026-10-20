from rest_framework import serializers

from tenants.models import Papel

from .models import NegocioPublico


class NegocioPublicoSerializer(serializers.ModelSerializer):
    class Meta:
        model = NegocioPublico
        fields = ['id', 'schema_name', 'nome', 'nicho', 'tipo_agenda', 'tipo_objeto', 'cidade', 'latitude', 'longitude', 'logo_url', 'descricao']


# ---------------------------------------------------------------------------
# Formatos de entrada e saída (documentação OpenAPI das APIViews)
# ---------------------------------------------------------------------------

class ServicoVitrineSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    nome = serializers.CharField()
    descricao = serializers.CharField()
    duracao = serializers.IntegerField(help_text='Minutos.')
    preco = serializers.DecimalField(max_digits=10, decimal_places=2)
    taxa_cancelamento = serializers.DecimalField(max_digits=10, decimal_places=2)


class MembroEquipeSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    nome = serializers.CharField()
    funcao = serializers.CharField()
    papel = serializers.ChoiceField(choices=Papel.choices)


class HorarioNegocioSerializer(serializers.Serializer):
    dia = serializers.IntegerField(min_value=0, max_value=6, help_text='0 = segunda ... 6 = domingo.')
    ativo = serializers.BooleanField()
    abertura = serializers.CharField(allow_null=True, help_text='HH:MM')
    fechamento = serializers.CharField(allow_null=True, help_text='HH:MM')


class DisponibilidadeSerializer(serializers.Serializer):
    data = serializers.DateField()
    slots = serializers.ListField(
        child=serializers.DateTimeField(), help_text='Inícios livres, em ISO 8601 com fuso.',
    )


class CriarAgendamentoSerializer(serializers.Serializer):
    servico_ids = serializers.ListField(child=serializers.IntegerField())
    data_hora = serializers.DateTimeField(help_text='ISO 8601; precisa ser no futuro.')
    colaborador_id = serializers.IntegerField(required=False, allow_null=True)
    objeto_id = serializers.IntegerField(
        required=False, allow_null=True, help_text='Pet ou veículo do consumidor (obrigatório em agenda por esteira).',
    )

