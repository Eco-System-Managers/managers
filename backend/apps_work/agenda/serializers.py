from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers
from .models import Agendamento, AgendamentoServico, OrigemAtendimento, PagamentoAgendamento


class AgendamentoServicoSerializer(serializers.ModelSerializer):
    servico_nome = serializers.ReadOnlyField(source='servico.nome')
    servico_duracao = serializers.ReadOnlyField(source='servico.duracao')

    class Meta:
        model = AgendamentoServico
        fields = '__all__'


class PagamentoAgendamentoSerializer(serializers.ModelSerializer):
    class Meta:
        model = PagamentoAgendamento
        fields = ['id', 'forma', 'valor']


class AgendamentoSerializer(serializers.ModelSerializer):
    servicos = AgendamentoServicoSerializer(many=True, read_only=True)
    pagamentos = PagamentoAgendamentoSerializer(many=True, read_only=True)
    cliente_nome = serializers.ReadOnlyField(source='cliente.nome')
    cliente_telefone = serializers.ReadOnlyField(source='cliente.telefone')
    colaborador_nome = serializers.SerializerMethodField()
    servico_id = serializers.IntegerField(write_only=True, required=False, allow_null=True)

    @extend_schema_field(serializers.CharField(allow_null=True))
    def get_colaborador_nome(self, obj):
        if obj.colaborador:
            nome = obj.colaborador.user.get_full_name().strip()
            return nome if nome else obj.colaborador.user.email
        return None

    def create(self, validated_data):
        servico_id = validated_data.pop('servico_id', None)
        agendamento = super().create(validated_data)
        if servico_id:
            from apps_work.servicos.models import Servico
            try:
                servico = Servico.objects.get(id=servico_id)
                AgendamentoServico.objects.create(
                    agendamento=agendamento,
                    servico=servico,
                    preco_cobrado=servico.preco,
                    desconto=0,
                )
            except Servico.DoesNotExist:
                pass
        return agendamento

    class Meta:
        model = Agendamento
        fields = '__all__'


# ---------------------------------------------------------------------------
# Formatos de entrada e saída (documentação OpenAPI das APIViews)
# ---------------------------------------------------------------------------

class PendenciaServicoSerializer(serializers.Serializer):
    servico_id = serializers.IntegerField(help_text='Id do Servico, na agenda e no kanban.')
    nome = serializers.CharField()
    preco = serializers.DecimalField(max_digits=10, decimal_places=2)


class PendenciaCobrancaSerializer(serializers.Serializer):
    origem = serializers.ChoiceField(choices=OrigemAtendimento.choices)
    id = serializers.IntegerField(help_text='Id do agendamento ou do atendimento do kanban.')
    data = serializers.DateField()
    cliente_id = serializers.IntegerField()
    cliente_nome = serializers.CharField()
    servico_nome = serializers.CharField()
    valor = serializers.DecimalField(max_digits=10, decimal_places=2)
    servicos = PendenciaServicoSerializer(many=True)


class SlotSerializer(serializers.Serializer):
    horario = serializers.CharField(help_text='HH:MM')
    disponivel = serializers.BooleanField()

