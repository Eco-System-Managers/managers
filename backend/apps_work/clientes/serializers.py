from rest_framework import serializers
from .models import Cliente, ObjetoCliente, Pet, Veiculo
from .validators import validar_cpf, validar_telefone_br, validar_placa_br


class VeiculoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Veiculo
        fields = ['id', 'cliente', 'placa', 'marca', 'modelo', 'cor', 'criado_em']
        read_only_fields = ['id', 'criado_em']

    def validate_placa(self, value):
        return validar_placa_br(value)


class PetSerializer(serializers.ModelSerializer):
    class Meta:
        model = Pet
        fields = ['id', 'cliente', 'nome', 'especie', 'raca', 'porte', 'data_nascimento', 'criado_em']
        read_only_fields = ['id', 'criado_em']


class ObjetoClienteSerializer(serializers.ModelSerializer):
    detalhe = serializers.SerializerMethodField()

    class Meta:
        model = ObjetoCliente
        fields = ['id', 'tipo', 'criado_em', 'detalhe']
        read_only_fields = ['id', 'tipo', 'criado_em']

    def get_detalhe(self, obj):
        if obj.tipo == 'veiculo':
            return VeiculoSerializer(obj.veiculo).data
        if obj.tipo == 'pet':
            return PetSerializer(obj.pet).data
        return None  # pragma: no cover — tipo é sempre 'veiculo' ou 'pet' (TIPO_CHOICES)


class ClienteSerializer(serializers.ModelSerializer):
    veiculos = serializers.SerializerMethodField()
    pets = serializers.SerializerMethodField()
    # A foto vem do cadastro do consumidor e é privada: o banco guarda só a
    # chave, e o endereço é assinado a cada resposta. Cliente cadastrado à mão
    # pelo painel simplesmente não tem foto.
    foto = serializers.SerializerMethodField()

    class Meta:
        model = Cliente
        fields = [
            'id', 'nome', 'telefone', 'email', 'cpf', 'data_nascimento',
            'cep', 'endereco', 'numero_endereco',
            'observacao',
            'alergia',
            'convenio', 'carteirinha', 'plano', 'validade_plano',
            'criado_em', 'origem',
            'veiculos', 'pets', 'foto',
        ]
        # origem é definida por quem cria o cadastro, nunca pelo cliente da API.
        read_only_fields = ['id', 'criado_em', 'origem', 'veiculos', 'pets', 'foto']

    # Campos cuja fonte é o cadastro do consumidor no schema público. Para
    # cliente vindo do Service Manage eles são espelho: aceitar edição pelo
    # painel só criaria um valor que a próxima sincronização apaga sem aviso.
    CAMPOS_SINCRONIZADOS = [
        'nome', 'telefone', 'cpf', 'data_nascimento',
        'cep', 'endereco', 'numero_endereco',
    ]

    def get_foto(self, obj) -> str:
        from apps_work.empresa.services import ArmazenamentoImagemService
        return ArmazenamentoImagemService().url(obj.foto_chave)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        instance = getattr(self, 'instance', None)
        if instance is not None and getattr(instance, 'origem', None) == Cliente.ORIGEM_SERVICEMANAGE:
            # read_only em vez de recusar o request: o painel manda o formulário
            # inteiro em cada PATCH, então rejeitar travaria também a edição de
            # observação e alergia, que continuam sendo do negócio.
            for campo in self.CAMPOS_SINCRONIZADOS:
                self.fields[campo].read_only = True

    def validate_cpf(self, value):
        if not value:
            return value
        cpf_limpo = validar_cpf(value)
        qs = Cliente.objects.filter(cpf=cpf_limpo)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError('CPF já cadastrado para outro cliente.')
        return cpf_limpo

    def validate_telefone(self, value):
        if not value:
            raise serializers.ValidationError('Telefone é obrigatório.')
        return validar_telefone_br(value)

    def get_veiculos(self, obj):
        # obj.objetos uses prefetch cache when set in viewset get_queryset
        veiculos = [o.veiculo for o in obj.objetos.all() if o.tipo == 'veiculo']
        return VeiculoSerializer(veiculos, many=True).data

    def get_pets(self, obj):
        pets = [o.pet for o in obj.objetos.all() if o.tipo == 'pet']
        return PetSerializer(pets, many=True).data
