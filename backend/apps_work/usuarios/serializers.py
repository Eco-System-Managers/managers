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
        fields = '__all__'


class ConviteColaboradorSerializer(serializers.ModelSerializer):
    class Meta:
        model = ConviteColaborador
        fields = ['id', 'nome', 'email', 'aceito', 'criado_em', 'expira_em']
        read_only_fields = ['id', 'aceito', 'criado_em', 'expira_em']
