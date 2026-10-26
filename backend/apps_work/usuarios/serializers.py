from decimal import Decimal

from django.db import connection
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from core.links import link_convite
from tenants.models import Membro, Papel
from .models import Colaborador, ConviteColaborador, VinculoColaborador


class ColaboradorSerializer(serializers.ModelSerializer):
    nome = serializers.CharField(max_length=150, required=False, allow_blank=True)
    email = serializers.SerializerMethodField()
    tem_acesso = serializers.BooleanField(read_only=True, help_text='Tem login. Quem não tem só aparece nos filtros.')
    papel = serializers.SerializerMethodField()

    class Meta:
        model = Colaborador
        fields = [
            'id', 'nome', 'email', 'tem_acesso', 'funcao', 'tipo', 'comissao_percentual', 'pode_cobrar',
            'papel', 'ativo', 'criado_em',
        ]
        # Ativação não passa pela edição comum: tem actions próprias do
        # proprietário. O papel nem é campo do Colaborador — vem do Membro.
        read_only_fields = ['ativo', 'criado_em']
        extra_kwargs = {
            'comissao_percentual': {'help_text': 'Só para parceiro: a parte dele (0 a 100). Nulo é sem acordo.'},
            'pode_cobrar': {'help_text': 'Só pesa para o colaborador comum; parceiro e dono cobram sempre.'},
        }

    @extend_schema_field(serializers.EmailField(allow_blank=True))
    def get_email(self, obj) -> str:
        return obj.user.email if obj.user_id else ''

    @extend_schema_field(serializers.ChoiceField(choices=Papel.choices, allow_null=True))
    def get_papel(self, obj):
        # Anotado pelo ColaboradorViewSet; fora dele (ex.: /me/), consulta.
        if hasattr(obj, 'papel'):
            return obj.papel
        if not obj.user_id:
            return None
        return Membro.papel_no_schema(obj.user, connection.schema_name)

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['nome'] = instance.nome_exibido
        return data

    def validate_comissao_percentual(self, valor):
        if valor is not None and not (Decimal('0') <= valor <= Decimal('100')):
            raise serializers.ValidationError('A comissão vai de 0 a 100.')
        return valor

    def validate(self, attrs):
        # Sem login, o nome é a única identificação: obrigatório ao criar.
        if self.instance is None and not attrs.get('nome', '').strip():
            raise serializers.ValidationError({'nome': 'Informe o nome.'})
        tipo = attrs.get('tipo', self.instance.tipo if self.instance else VinculoColaborador.PARCEIRO)
        if tipo == VinculoColaborador.COLABORADOR:
            # colaborador comum não tem comissão: o dinheiro é do negócio
            attrs['comissao_percentual'] = None
        return attrs


class ConvidarColaboradorSerializer(serializers.Serializer):
    email = serializers.EmailField()


class ConviteColaboradorSerializer(serializers.ModelSerializer):
    # o mesmo link do e-mail, para o dono mandar por WhatsApp quando o e-mail
    # não chega. só o proprietário vê convites, então o token não vaza
    link = serializers.SerializerMethodField()

    class Meta:
        model = ConviteColaborador
        fields = ['id', 'nome', 'email', 'colaborador', 'aceito', 'criado_em', 'expira_em', 'link']
        read_only_fields = ['id', 'colaborador', 'aceito', 'criado_em', 'expira_em', 'link']

    @extend_schema_field(serializers.URLField())
    def get_link(self, obj) -> str:
        return link_convite(obj.token)


class ConviteInfoSerializer(serializers.Serializer):
    """O que a tela de aceite mostra antes de a pessoa definir a senha."""
    nome = serializers.CharField()
    email = serializers.EmailField()
    expira_em = serializers.DateTimeField()


class AceitarConviteSerializer(serializers.Serializer):
    senha = serializers.CharField(write_only=True)
