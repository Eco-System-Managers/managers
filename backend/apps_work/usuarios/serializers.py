from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Colaborador, ConviteColaborador


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'first_name', 'last_name', 'email']


class ColaboradorSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = Colaborador
        fields = ['id', 'user', 'funcao', 'role', 'ativo', 'criado_em']
        # Papel e ativação não passam pela edição comum: o papel vem do
        # UserTenant, e ativar/desativar tem actions próprias do proprietário.
        read_only_fields = ['role', 'ativo', 'criado_em']


class ConviteColaboradorSerializer(serializers.ModelSerializer):
    class Meta:
        model = ConviteColaborador
        fields = ['id', 'nome', 'email', 'aceito', 'criado_em', 'expira_em']
        read_only_fields = ['id', 'aceito', 'criado_em', 'expira_em']
