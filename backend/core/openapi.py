"""Schemas OpenAPI (drf-spectacular): um por produto, para dois clients Dart.

- Work Manage:    /api/v1/schema/    (Swagger UI em /api/v1/schema/docs/)
- Service Manage: /api/sm/v1/schema/ (Swagger UI em /api/sm/v1/schema/docs/)

Arquivos versionados em backend/openapi/, gerados por
`manage.py gerar_openapi` — é deles que o front gera os clients.
"""
from drf_spectacular.contrib.rest_framework_simplejwt import SimpleJWTScheme
from drf_spectacular.extensions import OpenApiAuthenticationExtension

from core import rotas


def apenas_work(endpoints):
    """PREPROCESSING_HOOK: só as rotas do Work Manage."""
    return [e for e in endpoints if e[0].startswith(rotas.WORK)]


def apenas_servicemanage(endpoints):
    """PREPROCESSING_HOOK: só as rotas do Service Manage."""
    return [e for e in endpoints if e[0].startswith(rotas.SERVICEMANAGE)]


CONFIG_WORK = {
    'TITLE': 'Work Manage API',
    'DESCRIPTION': 'API do painel do negócio (B2B).',
    'PREPROCESSING_HOOKS': ['core.openapi.apenas_work'],
}

CONFIG_SERVICEMANAGE = {
    'TITLE': 'Service Manage API',
    'DESCRIPTION': 'API do app do cliente final (B2C).',
    'PREPROCESSING_HOOKS': ['core.openapi.apenas_servicemanage'],
}


class TenantJWTScheme(SimpleJWTScheme):
    """A extensão do SimpleJWT só reconhece a classe exata, não subclasses."""
    target_class = 'core.authentication.TenantJWTAuthentication'
    name = 'workmanageJWT'


class ConsumidorJWTScheme(OpenApiAuthenticationExtension):
    target_class = 'apps_serv.autenticacao.authentication.ConsumidorJWTAuthentication'
    name = 'servicemanageJWT'

    def get_security_definition(self, auto_schema):
        return {'type': 'http', 'scheme': 'bearer', 'bearerFormat': 'JWT'}


# ---------------------------------------------------------------------------
# Contrato de erro no schema
# ---------------------------------------------------------------------------

_ERRO = {
    'type': 'object',
    'description': 'Contrato único de erro da API (core/excecoes.py).',
    'properties': {
        'detail': {'type': 'string', 'description': 'Mensagem para o usuário.'},
        'code': {'type': 'string', 'description': 'Identificador estável do erro.'},
        'fields': {
            'type': 'object',
            'description': 'Só em erro de validação: {campo: [mensagens]}.',
            'additionalProperties': {'type': 'array', 'items': {'type': 'string'}},
        },
    },
    'required': ['detail', 'code'],
}

_STATUS_DE_ERRO = {
    '400': 'Requisição inválida ou regra de negócio violada.',
    '401': 'Não autenticado ou sessão expirada.',
    '403': 'Sem permissão.',
    '404': 'Não encontrado.',
    '429': 'Limite de requisições atingido.',
}


def adicionar_erros(result, generator, request, public):
    """POSTPROCESSING_HOOK: o contrato de erro em toda operação.

    Sem isso, o client gerado não teria tipo para o corpo de um 4xx.
    """
    result.setdefault('components', {}).setdefault('schemas', {})['Erro'] = _ERRO
    ref = {'content': {'application/json': {'schema': {'$ref': '#/components/schemas/Erro'}}}}
    for rota in result.get('paths', {}).values():
        for operacao in rota.values():
            respostas = operacao.setdefault('responses', {})
            for codigo, descricao in _STATUS_DE_ERRO.items():
                respostas.setdefault(codigo, {'description': descricao, **ref})
            # Erros declarados na própria operação (ex.: 503) também usam o contrato.
            for codigo, resposta in respostas.items():
                if codigo >= '400' and 'content' not in resposta:
                    resposta.update(ref)
    return result


# ---------------------------------------------------------------------------
# Peças reaproveitadas nas anotações (@extend_schema) das APIViews
# ---------------------------------------------------------------------------

from drf_spectacular.types import OpenApiTypes  # noqa: E402
from drf_spectacular.utils import OpenApiParameter  # noqa: E402
from rest_framework import serializers  # noqa: E402

from core.sessao import CABECALHO_PLATAFORMA  # noqa: E402


class MensagemSerializer(serializers.Serializer):
    """Resposta de sucesso que só confirma a ação: {"detail": "..."}."""
    detail = serializers.CharField()


PLATAFORMA = OpenApiParameter(
    name=CABECALHO_PLATAFORMA,
    type=OpenApiTypes.STR,
    location=OpenApiParameter.HEADER,
    required=False,
    enum=['mobile'],
    description=(
        'Envie `mobile` no app: o refresh vem e vai no corpo. Sem o cabeçalho '
        '(web), o refresh fica só no cookie httpOnly.'
    ),
)
