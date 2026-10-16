from rest_framework import serializers

from apps_work.clientes.validators import validar_cpf, validar_telefone_br

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


class ObjetoConsumidorSerializer(serializers.ModelSerializer):
    class Meta:
        model = ObjetoConsumidor
        fields = ['id', 'tipo', 'dados', 'nome_exibicao', 'criado_em']
        read_only_fields = ['nome_exibicao', 'criado_em']


class AgendamentoConsumidorSerializer(serializers.ModelSerializer):
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
