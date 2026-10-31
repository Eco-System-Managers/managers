from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers
from django.utils import timezone
from .models import Agendamento, AgendamentoServico, Bloqueio, OrigemAtendimento, PagamentoAgendamento


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
        return obj.colaborador.nome_exibido if obj.colaborador else None

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
        # Os dois só mudam pela cobrança (cobrar/), em comum acordo com o
        # cliente: por PATCH seriam ignorados.
        read_only_fields = ['acrescimo', 'acrescimo_motivo']
        extra_kwargs = {
            'acrescimo': {'help_text': 'O que o atendimento custou a mais, acertado na cobrança. Zero sem acréscimo.'},
            'acrescimo_motivo': {'help_text': 'O motivo do acréscimo, que o cliente vê no app ("tempo excedido").'},
        }


class BloqueioSerializer(serializers.ModelSerializer):
    colaborador_nome = serializers.SerializerMethodField()

    @extend_schema_field(serializers.CharField(allow_null=True))
    def get_colaborador_nome(self, obj):
        # nulo no bloqueio do negócio, que não é de ninguém em particular
        return obj.colaborador.nome_exibido if obj.colaborador else None

    class Meta:
        model = Bloqueio
        fields = [
            'id', 'colaborador', 'colaborador_nome', 'data_inicio', 'data_fim',
            'hora_inicio', 'hora_fim', 'motivo', 'criado_em',
        ]
        extra_kwargs = {
            'colaborador': {
                'help_text': 'De quem é a agenda bloqueada. Nulo (ou omitido) é o negócio inteiro: vale para '
                             'todos os profissionais e para a esteira. Só o proprietário cria e exclui esse.',
            },
            'data_fim': {'help_text': 'Nulo é o bloqueio fixo: vale todos os dias a partir do início.'},
            'hora_inicio': {'help_text': 'Nulo junto com hora_fim: o dia inteiro.'},
        }

    def validate(self, attrs):
        if attrs['data_inicio'] < timezone.localdate():
            raise serializers.ValidationError({'data_inicio': 'O bloqueio começa hoje ou depois.'})
        data_fim = attrs.get('data_fim')
        if data_fim and data_fim < attrs['data_inicio']:
            raise serializers.ValidationError({'data_fim': 'O fim vem depois do início.'})

        hora_inicio, hora_fim = attrs.get('hora_inicio'), attrs.get('hora_fim')
        if (hora_inicio is None) != (hora_fim is None):
            raise serializers.ValidationError(
                {'hora_fim': 'Informe o início e o fim, ou nenhum dos dois para o dia inteiro.'},
            )
        if hora_inicio is not None and hora_fim <= hora_inicio:
            raise serializers.ValidationError({'hora_fim': 'O fim vem depois do início.'})
        return attrs


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
    cliente_id = serializers.IntegerField(
        allow_null=True, help_text='Nulo no avulso da esteira, que não tem cliente.',
    )
    cliente_nome = serializers.CharField(help_text='No avulso da esteira, a identificação ("Hilux branca").')
    servico_nome = serializers.CharField()
    valor = serializers.DecimalField(max_digits=10, decimal_places=2)
    servicos = PendenciaServicoSerializer(many=True)


class SlotSerializer(serializers.Serializer):
    horario = serializers.CharField(help_text='HH:MM')
    disponivel = serializers.BooleanField()

