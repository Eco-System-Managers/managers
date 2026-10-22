import re
import unicodedata
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from tenants.models import Tenant


# Cabe o sufixo de desempate ("_999") sem passar do limite de 63 do Postgres.
_TAMANHO_BASE = 56
_RESERVADOS = {'public', 'information_schema'}


def _slug(name: str) -> str:
    """Base do schema: só [a-z0-9_], sem começar por dígito nem por pg_.

    Pode voltar vazia, quando o nome não tem nenhuma letra ou número
    aproveitável — quem chama decide o que fazer.
    """
    normalized = unicodedata.normalize('NFD', name.lower().strip())
    ascii_only = ''.join(c for c in normalized if ord(c) < 128)
    slug = re.sub(r'[^a-z0-9]+', '_', ascii_only).strip('_')
    # Começar por dígito ou por pg_ é inválido como schema no Postgres.
    if slug and (slug[0].isdigit() or slug.startswith('pg_') or slug in _RESERVADOS):
        slug = f'e_{slug}'
    return slug[:_TAMANHO_BASE].rstrip('_')


def gerar_schema_name(nome_empresa: str) -> str:
    """Schema livre para o nome: a base, ou a base com _2, _3… se já existir.

    Duas empresas podem ter o mesmo nome; o que precisa ser único é o schema.
    """
    base = _slug(nome_empresa)
    candidato, n = base, 1
    while Tenant.objects.filter(schema_name=candidato).exists():
        n += 1
        candidato = f'{base}_{n}'
    return candidato


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
        if not _slug(value):
            raise serializers.ValidationError('Use ao menos uma letra ou número no nome da empresa.')
        return value

    def create(self, validated_data):
        from .services import OnboardingService
        return OnboardingService().registrar_empresa(
            nome_empresa=validated_data['nome_empresa'],
            schema_name=gerar_schema_name(validated_data['nome_empresa']),
            nome=validated_data['nome'],
            email=validated_data['email'],
            senha=validated_data['senha'],
        )


# ---------------------------------------------------------------------------
# Formatos de entrada e saída (documentação OpenAPI das APIViews)
# ---------------------------------------------------------------------------

class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    senha = serializers.CharField()


class SessaoSerializer(serializers.Serializer):
    """Resposta de login, cadastro, renovação e aceite de convite."""
    access = serializers.CharField()
    schema_name = serializers.CharField()
    empresa = serializers.CharField()
    refresh = serializers.CharField(
        required=False, help_text='Só para o app mobile (cabeçalho X-Client-Platform: mobile).',
    )


class EmailSerializer(serializers.Serializer):
    email = serializers.EmailField()


class VerificarCodigoSerializer(serializers.Serializer):
    email = serializers.EmailField()
    codigo = serializers.CharField()


class ConfirmarCadastroSerializer(serializers.Serializer):
    email = serializers.EmailField()
    codigo = serializers.CharField()


class NovaSenhaSerializer(serializers.Serializer):
    email = serializers.EmailField()
    codigo = serializers.CharField()
    nova_senha = serializers.CharField()


class RefreshSerializer(serializers.Serializer):
    refresh = serializers.CharField(
        required=False,
        help_text='Só no app mobile (cabeçalho X-Client-Platform: mobile); no web o refresh vai no cookie.',
    )

