from rest_framework import serializers
from apps_work.clientes.serializers import ObjetoClienteSerializer
from core.permissions import eh_colaborador_comum
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
        source='objeto.cliente.telefone', read_only=True, allow_null=True,
        help_text='Nulo no avulso e para o colaborador comum, que não fala com o cliente.',
    )
    avulso = serializers.BooleanField(
        read_only=True, help_text='true quando não há veículo nem pet: o atendimento é só a identificação.',
    )
    servico_nome = serializers.CharField(source='servico.nome', read_only=True)
    servico_preco = serializers.DecimalField(
        source='servico.preco', max_digits=8, decimal_places=2, read_only=True, allow_null=True,
        help_text='Nulo para o colaborador comum, que não vê valores.',
    )
    servico_duracao = serializers.IntegerField(source='servico.duracao', read_only=True)
    pagamentos = PagamentoAtendimentoSerializer(
        many=True, read_only=True, help_text='Vazio para o colaborador comum, que não vê valores.',
    )
    duracao_prevista = serializers.IntegerField(
        read_only=True, help_text='Minutos: a duração do serviço mais o tempo a mais previsto.',
    )
    # Só na entrada: o dono recebendo mesmo com o dia lotado ou a hora cheia.
    ignorar_limite = serializers.BooleanField(
        write_only=True, required=False, default=False,
        help_text='Recebe mesmo passando do máximo do dia ou sem vaga na hora (o limite é aviso para o negócio).',
    )

    # O que o colaborador comum não vê: o telefone do cliente e o dinheiro.
    # Ele só move os cards; falar com o cliente e cobrar é do dono e do parceiro.
    _RESERVADOS = ('cliente_telefone', 'servico_preco', 'desconto', 'acrescimo', 'acrescimo_motivo', 'pagamentos')

    def _esconde_reservados(self) -> bool:
        # Calculado uma vez por serializer: na lista o filho é o mesmo objeto
        # para todos os cards, e o vínculo não muda no meio da resposta.
        if not hasattr(self, '_esconde'):
            request = self.context.get('request')
            self._esconde = request is not None and eh_colaborador_comum(request)
        return self._esconde

    def to_representation(self, instance):
        data = super().to_representation(instance)
        if self._esconde_reservados():
            for campo in self._RESERVADOS:
                data[campo] = [] if campo == 'pagamentos' else None
        return data

    class Meta:
        model = AtendimentoKanban
        fields = [
            'id', 'etapa', 'etapa_nome',
            'objeto', 'objeto_detalhe', 'cliente_nome',
            'cliente_telefone', 'identificacao', 'avulso',
            'servico', 'servico_nome', 'servico_preco', 'servico_duracao',
            'observacao', 'data', 'horario_entrada', 'pago', 'faltou', 'desconto', 'acrescimo', 'acrescimo_motivo',
            'pagamentos', 'minutos_extras', 'duracao_prevista', 'pronto_em', 'ignorar_limite', 'criado_em',
        ]
        # desconto, acrescimo e o motivo só mudam pela cobrança (cobrar/), em
        # comum acordo com o cliente: por PATCH seriam ignorados. Os três são
        # anuláveis no contrato porque saem nulos para o colaborador comum.
        read_only_fields = ['desconto', 'acrescimo', 'acrescimo_motivo', 'pronto_em', 'criado_em']
        extra_kwargs = {
            'desconto': {
                'allow_null': True,
                'help_text': 'O desconto dado na cobrança. Zero sem desconto; nulo para o colaborador comum.',
            },
            'acrescimo': {
                'allow_null': True,
                'help_text': 'O que o atendimento custou a mais, acertado na cobrança. Zero sem acréscimo; nulo '
                             'para o colaborador comum.',
            },
            'acrescimo_motivo': {
                'allow_null': True,
                'help_text': 'O motivo do acréscimo, que o cliente vê no app ("tempo excedido"); nulo para o '
                             'colaborador comum.',
            },
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
