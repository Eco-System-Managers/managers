from django.db import connection
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from tenants.models import Membro, Papel
from django.contrib.auth.models import User
from .models import Colaborador, ConviteColaborador


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'first_name', 'last_name', 'email']


class ColaboradorSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    papel = serializers.SerializerMethodField()

    class Meta:
        model = Colaborador
        fields = ['id', 'user', 'funcao', 'papel', 'ativo', 'criado_em']
        # Ativação não passa pela edição comum: tem actions próprias do
        # proprietário. O papel nem é campo do Colaborador — vem do Membro.
        read_only_fields = ['ativo', 'criado_em']

    @extend_schema_field(serializers.ChoiceField(choices=Papel.choices, allow_null=True))
    def get_papel(self, obj):
        # Anotado pelo ColaboradorViewSet; fora dele (ex.: /me/), consulta.
        if hasattr(obj, 'papel'):
            return obj.papel
        return Membro.papel_no_schema(obj.user, connection.schema_name)


class ConviteColaboradorSerializer(serializers.ModelSerializer):
    class Meta:
        model = ConviteColaborador
        fields = ['id', 'nome', 'email', 'aceito', 'criado_em', 'expira_em']
        read_only_fields = ['id', 'aceito', 'criado_em', 'expira_em']


class ConviteInfoSerializer(serializers.Serializer):
    """O que a tela de aceite mostra antes de a pessoa definir a senha."""
    nome = serializers.CharField()
    email = serializers.EmailField()
    expira_em = serializers.DateTimeField()


class AceitarConviteSerializer(serializers.Serializer):
    senha = serializers.CharField(write_only=True)
