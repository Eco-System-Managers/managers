from drf_spectacular.utils import PolymorphicProxySerializer, extend_schema_field
from rest_framework import serializers

from apps_work.clientes.models import PortePet
from apps_work.clientes.validators import normalizar_porte, validar_cpf, validar_placa_br, validar_telefone_br

from apps_serv.vitrine.serializers import NegocioPublicoSerializer

from .models import AgendamentoConsumidor, Consumidor, ObjetoConsumidor


class CadastroConsumidorSerializer(serializers.Serializer):
    nome = serializers.CharField(max_length=255)
    email = serializers.EmailField()
    senha = serializers.CharField(min_length=8, write_only=True)
    # Obrigatorio: a conta vira Cliente nos negocios vinculados, e la o
    # telefone e o canal de contato. A tela de criar conta ja o coleta.
    telefone = serializers.CharField(max_length=20)


class ConsumidorSerializer(serializers.ModelSerializer):
    # O app recebe uma URL pronta em `foto`; o banco guarda só o caminho. A
    # assinatura é gerada a cada resposta porque tem validade curta.
    foto = serializers.SerializerMethodField()

    class Meta:
        model = Consumidor
        fields = [
            'id', 'nome', 'email', 'telefone', 'foto', 'criado_em',
            'cpf', 'data_nascimento', 'cep', 'endereco', 'numero_endereco',
        ]

    def get_foto(self, obj) -> str:
        from apps_work.empresa.services import ArmazenamentoImagemService
        return ArmazenamentoImagemService().url(obj.foto_chave)


class ConsumidorUpdateSerializer(serializers.ModelSerializer):
    """Edicao do proprio cadastro pelo app.

    E-mail continua de fora, mas o motivo mudou. Nao e mais a chave que liga o
    consumidor ao Cliente de cada tenant — quem faz isso agora e
    `Cliente.consumidor_id`, que nao depende de dado que a pessoa possa trocar.

    O que sobra e que o e-mail e a credencial de login: muda-lo exige validar
    unicidade e confirmar a posse do endereco novo. Isso e um fluxo proprio, e
    nao um efeito colateral de salvar o perfil.
    """

    class Meta:
        model = Consumidor
        fields = [
            'nome', 'telefone', 'cpf', 'data_nascimento',
            'cep', 'endereco', 'numero_endereco',
        ]

    def validate_nome(self, value):
        if not value.strip():
            raise serializers.ValidationError('Nome e obrigatorio.')
        return value.strip()

    def validate_telefone(self, value):
        if not value:
            raise serializers.ValidationError('Telefone e obrigatorio.')
        return validar_telefone_br(value)

    def validate_cpf(self, value):
        if not value:
            return value
        cpf_limpo = validar_cpf(value)
        qs = Consumidor.objects.filter(cpf=cpf_limpo).exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError('CPF ja cadastrado para outra conta.')
        return cpf_limpo


class DadosVeiculoSerializer(serializers.Serializer):
    placa = serializers.CharField(max_length=10)
    marca = serializers.CharField(max_length=50)
    modelo = serializers.CharField(max_length=100)
    cor = serializers.CharField(max_length=50, required=False, allow_blank=True, default='')

    def validate_placa(self, valor):
        return validar_placa_br(valor)


class DadosPetSerializer(serializers.Serializer):
    nome = serializers.CharField(max_length=100)
    especie = serializers.CharField(max_length=50)
    porte = serializers.ChoiceField(choices=PortePet.choices)
    raca = serializers.CharField(max_length=100, required=False, allow_blank=True, default='')

    def to_internal_value(self, data):
        # Aceita o rótulo ('Médio') que o app mandava antes do enum.
        if isinstance(data, dict) and 'porte' in data:
            data = {**data, 'porte': normalizar_porte(data['porte']) or data['porte']}
        return super().to_internal_value(data)


_DADOS_OBJETO = PolymorphicProxySerializer(
    component_name='DadosObjeto',
    serializers=[DadosPetSerializer, DadosVeiculoSerializer],
    resource_type_field_name=None,
)


@extend_schema_field(_DADOS_OBJETO)
class DadosObjetoField(serializers.JSONField):
    """`dados` de um pet ou veículo: DadosPet ou DadosVeiculo, conforme o `tipo`."""


class ObjetoConsumidorSerializer(serializers.ModelSerializer):
    dados = DadosObjetoField()

    class Meta:
        model = ObjetoConsumidor
        fields = ['id', 'tipo', 'dados', 'nome_exibicao', 'criado_em']
        read_only_fields = ['nome_exibicao', 'criado_em']


class ServicoAgendadoSerializer(serializers.Serializer):
    """Foto do serviço no momento do agendamento (não muda se o negócio mudar o preço)."""
    nome = serializers.CharField()
    duracao = serializers.IntegerField(help_text='Minutos.')
    preco = serializers.DecimalField(max_digits=10, decimal_places=2)
    taxa_cancelamento = serializers.DecimalField(max_digits=10, decimal_places=2)


class ObjetoAgendadoSerializer(serializers.Serializer):
    """Pet ou veículo levado ao atendimento: tipo, nome de exibição e os dados do tipo."""
    tipo = serializers.CharField()
    nome_exibicao = serializers.CharField()
    placa = serializers.CharField(required=False)
    marca = serializers.CharField(required=False)
    modelo = serializers.CharField(required=False)
    cor = serializers.CharField(required=False)
    nome = serializers.CharField(required=False)
    especie = serializers.CharField(required=False)
    porte = serializers.CharField(required=False)
    raca = serializers.CharField(required=False)


class AgendamentoConsumidorSerializer(serializers.ModelSerializer):
    # Preço como string em todo agendamento: os anteriores à #6 guardaram
    # float no JSON, e o DecimalField normaliza na saída.
    servicos = ServicoAgendadoSerializer(many=True, read_only=True)
    objeto_dados = ObjetoAgendadoSerializer(read_only=True, allow_null=True)

    # Preenchidos só na listagem da agenda, a partir do context — exigem uma
    # leitura no schema do negócio, cara demais para fazer por item. Ficam
    # nulos em qualquer outro uso do serializer (ex.: resposta do agendamento
    # recém-criado) e em agendamentos que não são de esteira.
    status_kanban = serializers.SerializerMethodField()
    etapa_nome = serializers.SerializerMethodField()
    # Tambem vem do context, mas por outro motivo: a logo vive no NegocioPublico
    # e mudaria a cada upload se fosse copiada para ca. Resolver por item seria
    # uma consulta por agendamento — a view monta o mapa da pagina de uma vez.
    logo_url = serializers.SerializerMethodField()

    class Meta:
        model = AgendamentoConsumidor
        fields = [
            'id', 'schema_name', 'agendamento_id', 'origem', 'negocio_nome', 'nicho',
            'servicos', 'profissional_nome', 'objeto_dados', 'data_hora',
            'duracao_total', 'valor_total', 'valor_taxa_cancelamento',
            'status', 'status_kanban', 'etapa_nome', 'logo_url', 'criado_em',
        ]

    def _status_kanban(self, obj) -> dict:
        return (self.context.get('status_kanban') or {}).get(obj.id, {})

    def get_status_kanban(self, obj) -> str | None:
        return self._status_kanban(obj).get('status_kanban')

    def get_etapa_nome(self, obj) -> str | None:
        return self._status_kanban(obj).get('etapa_nome')

    def get_logo_url(self, obj) -> str | None:
        return (self.context.get('logos') or {}).get(obj.schema_name) or None


# ---------------------------------------------------------------------------
# Formatos de entrada e saída (documentação OpenAPI das APIViews)
# ---------------------------------------------------------------------------

class FotoPerfilUploadSerializer(serializers.Serializer):
    foto = serializers.ImageField()


class VinculoNegocioSerializer(NegocioPublicoSerializer):
    """Negócio vinculado: os campos do NegocioPublico mais a data do vínculo."""
    vinculado_em = serializers.DateTimeField()

    class Meta(NegocioPublicoSerializer.Meta):
        fields = NegocioPublicoSerializer.Meta.fields + ['vinculado_em']


class CancelamentoAgendamentoSerializer(serializers.Serializer):
    detail = serializers.CharField()
    taxa = serializers.DecimalField(
        max_digits=10, decimal_places=2, help_text='Taxa de cancelamento cobrada (0.00 dentro do prazo).',
    )

