from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers
from apps_work.clientes.serializers import ObjetoClienteSerializer
from .models import AtendimentoKanban, EtapaKanban, PagamentoAtendimento


class EtapaKanbanSerializer(serializers.ModelSerializer):
    class Meta:
        model = EtapaKanban
        fields = ['id', 'nome', 'ordem', 'cor', 'pronto']
        # Uma só por negócio: muda pela ação pronto/, não por PATCH.
        read_only_fields = ['pronto']
        extra_kwargs = {
            'pronto': {'help_text': 'A etapa em que o atendimento está pronto; as depois dela também contam.'},
        }


class PagamentoAtendimentoSerializer(serializers.ModelSerializer):
    class Meta:
        model = PagamentoAtendimento
        fields = ['id', 'forma', 'valor']


class AtendimentoKanbanSerializer(serializers.ModelSerializer):
    etapa_nome = serializers.CharField(source='etapa.nome', read_only=True)
    # No avulso não há objeto nem cliente: os três saem nulos (allow_null é o
    # que faz o DRF devolver None em vez de quebrar em `None.cliente`).
    objeto_detalhe = ObjetoClienteSerializer(
        source='objeto', read_only=True, allow_null=True, help_text='Nulo no avulso.',
    )
    cliente_nome = serializers.CharField(
        source='objeto.cliente.nome', read_only=True, allow_null=True, help_text='Nulo no avulso.',
    )
    cliente_telefone = serializers.CharField(
        source='objeto.cliente.telefone', read_only=True, allow_null=True, help_text='Nulo no avulso.',
    )
    avulso = serializers.BooleanField(
        read_only=True, help_text='true quando não há veículo nem pet: o atendimento é só a identificação.',
    )
    servico_nome = serializers.CharField(source='servico.nome', read_only=True)
    servico_preco = serializers.DecimalField(source='servico.preco', max_digits=8, decimal_places=2, read_only=True)
    servico_duracao = serializers.IntegerField(source='servico.duracao', read_only=True)
    colaborador_nome = serializers.SerializerMethodField()
    pagamentos = PagamentoAtendimentoSerializer(many=True, read_only=True)
    duracao_prevista = serializers.IntegerField(
        read_only=True, help_text='Minutos: a duração do serviço mais o tempo a mais previsto.',
    )
    # Só na entrada: o dono recebendo mesmo com o dia lotado ou a hora cheia.
    ignorar_limite = serializers.BooleanField(
        write_only=True, required=False, default=False,
        help_text='Recebe mesmo passando do máximo do dia ou sem vaga na hora (o limite é aviso para o negócio).',
    )

    @extend_schema_field(serializers.CharField(allow_null=True))
    def get_colaborador_nome(self, obj):
        return obj.colaborador.nome_exibido if obj.colaborador else None

    class Meta:
        model = AtendimentoKanban
        fields = [
            'id', 'etapa', 'etapa_nome',
            'objeto', 'objeto_detalhe', 'cliente_nome',
            'cliente_telefone', 'identificacao', 'avulso',
            'servico', 'servico_nome', 'servico_preco', 'servico_duracao',
            'colaborador', 'colaborador_nome',
            'observacao', 'data', 'horario_entrada', 'pago', 'faltou', 'desconto', 'acrescimo', 'acrescimo_motivo',
            'pagamentos', 'minutos_extras', 'duracao_prevista', 'pronto_em', 'ignorar_limite', 'criado_em',
        ]
        # acrescimo e o motivo só mudam pela cobrança (cobrar/), em comum
        # acordo com o cliente: por PATCH seriam ignorados.
        read_only_fields = ['acrescimo', 'acrescimo_motivo', 'pronto_em', 'criado_em']
        extra_kwargs = {
            'acrescimo': {'help_text': 'O que o atendimento custou a mais, acertado na cobrança. Zero sem acréscimo.'},
            'acrescimo_motivo': {'help_text': 'O motivo do acréscimo, que o cliente vê no app ("tempo excedido").'},
            'objeto': {
                'help_text': 'O veículo ou pet. Opcional: sem ele o atendimento é avulso e a identificação '
                             'é obrigatória (400 avulso_sem_identificacao com os dois vazios).',
            },
            'identificacao': {
                'help_text': 'O texto que identifica o avulso no pátio ("Hilux branca", "ABC-1234").',
            },
            'minutos_extras': {'help_text': 'O tempo a mais previsto, em minutos. É do pátio: o preço não muda.'},
            'pronto_em': {'help_text': 'Quando o card chegou na etapa de pronto; nulo antes disso.'},
        }


class CapacidadeDoDiaSerializer(serializers.Serializer):
    """Quanto cabe no dia e quanto já há nele."""
    data = serializers.DateField()
    capacidade = serializers.IntegerField(allow_null=True, help_text='O máximo de atendimentos no dia; nulo é sem máximo.')
    vagas = serializers.IntegerField(help_text='Quantos atendimentos andam juntos.')
    ajustado = serializers.BooleanField(help_text='true quando a data tem um ajuste, fora do padrão da semana.')
    ocupados = serializers.IntegerField(help_text='Os atendimentos do dia, com ou sem hora; quem faltou não conta.')


class AjusteDoDiaRequestSerializer(serializers.Serializer):
    """Os dois números sempre vêm: `capacidade` nula é "sem máximo" de
    propósito, e omitida seria um "sem máximo" por acidente."""
    capacidade = serializers.IntegerField(
        allow_null=True, required=True, min_value=1, help_text='O máximo do dia; null é sem máximo.',
    )
    vagas = serializers.IntegerField(min_value=1, help_text='Quantos atendimentos andam juntos.')
