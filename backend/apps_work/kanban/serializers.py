from rest_framework import serializers
from apps_work.clientes.serializers import ObjetoClienteSerializer
from .models import AtendimentoKanban, EtapaKanban, PagamentoAtendimento


class EtapaKanbanSerializer(serializers.ModelSerializer):
    class Meta:
        model = EtapaKanban
        fields = ['id', 'nome', 'ordem', 'cor']


class PagamentoAtendimentoSerializer(serializers.ModelSerializer):
    class Meta:
        model = PagamentoAtendimento
        fields = ['id', 'forma', 'valor']


class AtendimentoKanbanSerializer(serializers.ModelSerializer):
    etapa_nome = serializers.CharField(source='etapa.nome', read_only=True)
    objeto_detalhe = ObjetoClienteSerializer(source='objeto', read_only=True)
    cliente_nome = serializers.CharField(source='objeto.cliente.nome', read_only=True)
    cliente_telefone = serializers.CharField(source='objeto.cliente.telefone', read_only=True, allow_null=True)
    servico_nome = serializers.CharField(source='servico.nome', read_only=True)
    servico_preco = serializers.DecimalField(source='servico.preco', max_digits=8, decimal_places=2, read_only=True)
    servico_duracao = serializers.IntegerField(source='servico.duracao', read_only=True)
    pagamentos = PagamentoAtendimentoSerializer(many=True, read_only=True)

    class Meta:
        model = AtendimentoKanban
        fields = [
            'id', 'etapa', 'etapa_nome',
            'objeto', 'objeto_detalhe', 'cliente_nome',
            'cliente_telefone',
            'servico', 'servico_nome', 'servico_preco', 'servico_duracao',
            'observacao', 'data', 'horario_entrada', 'pago', 'faltou', 'desconto', 'pagamentos', 'criado_em',
        ]
        read_only_fields = ['criado_em']
        # DRF geraria automaticamente um UniqueTogetherValidator pra
        # constraint kanban_atendimento_unique_slot (data + horario_entrada),
        # mas isso duplicaria a checagem já feita em
        # AtendimentoKanbanService.criar — e com uma mensagem/código
        # genéricos, diferente do formato {"detail", "code"} do projeto.
        # A regra de negócio (horário ocupado) fica só no service.
        validators = []
