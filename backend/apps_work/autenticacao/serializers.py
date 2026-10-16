import re
import unicodedata
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from tenants.models import Tenant


def _slug(name: str) -> str:
    normalized = unicodedata.normalize('NFD', name.lower().strip())
    ascii_only = ''.join(c for c in normalized if ord(c) < 128)
    return re.sub(r'[^a-z0-9]', '_', ascii_only)


class CadastroSerializer(serializers.Serializer):
    nome_empresa = serializers.CharField(max_length=255)
    nome = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    senha = serializers.CharField(write_only=True)

    def validate_email(self, value):
        value = value.lower().strip()
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError('Este e-mail já está em uso.')
        return value

    def validate_senha(self, value):
        validate_password(value)
        return value

    def validate_nome_empresa(self, value):
        schema_name = _slug(value)
        if Tenant.objects.filter(schema_name=schema_name).exists():
            raise serializers.ValidationError('Já existe uma empresa com esse nome.')
        return value

    def create(self, validated_data):
        from .services import OnboardingService
        return OnboardingService().registrar_empresa(
            nome_empresa=validated_data['nome_empresa'],
            schema_name=_slug(validated_data['nome_empresa']),
            nome=validated_data['nome'],
            email=validated_data['email'],
            senha=validated_data['senha'],
        )
