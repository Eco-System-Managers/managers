"""Contrato único de erro da API: `{"detail": str, "code": str, "fields"?: {...}}`.

- `detail`: mensagem para mostrar ao usuário
- `code`: identificador estável, para o front decidir o que fazer sem
  comparar texto
- `fields`: só em erro de validação, `{campo: [mensagens]}`

Toda resposta 4xx/5xx gerada pela API segue esse formato: exceções levantadas
passam pelo `tratar_excecao` (EXCEPTION_HANDLER), e respostas montadas à mão
usam `erro()`.
"""
from django.core.exceptions import PermissionDenied as DjangoPermissionDenied
from django.http import Http404
from rest_framework import exceptions, status
from rest_framework.response import Response
from rest_framework.views import exception_handler

# Código padrão por status, para quando quem levanta o erro não dá um próprio.
_CODIGO_POR_STATUS = {
    status.HTTP_400_BAD_REQUEST: 'invalido',
    status.HTTP_401_UNAUTHORIZED: 'nao_autenticado',
    status.HTTP_402_PAYMENT_REQUIRED: 'pagamento_necessario',
    status.HTTP_403_FORBIDDEN: 'sem_permissao',
    status.HTTP_404_NOT_FOUND: 'nao_encontrado',
    status.HTTP_405_METHOD_NOT_ALLOWED: 'metodo_nao_permitido',
    status.HTTP_409_CONFLICT: 'conflito',
    status.HTTP_429_TOO_MANY_REQUESTS: 'muitas_requisicoes',
}


class ErroDeNegocio(ValueError):
    """Regra de negócio violada — vira 400 (ou o status dado) no contrato.

    Herda de ValueError de propósito: services e testes que já tratam
    ValueError continuam funcionando, e quem levanta não precisa conhecer HTTP.
    """

    def __init__(self, detail: str, code: str = 'invalido', status_code: int = status.HTTP_400_BAD_REQUEST):
        super().__init__(detail)
        self.detail = detail
        self.code = code
        self.status_code = status_code


def erro(detail: str, code: str | None = None, status_code: int = status.HTTP_400_BAD_REQUEST) -> Response:
    """Resposta de erro montada à mão, no mesmo formato do handler.

    Para quando a view precisa de um efeito junto com o erro (apagar o cookie
    de refresh, por exemplo); no resto, prefira levantar a exceção.
    """
    return Response(
        {'detail': detail, 'code': code or _CODIGO_POR_STATUS.get(status_code, 'erro')},
        status=status_code,
    )


def corpo_de_erro(detail, code=None, status_code=400, fields=None) -> dict:
    corpo = {'detail': str(detail), 'code': code or _CODIGO_POR_STATUS.get(status_code, 'erro')}
    if fields:
        corpo['fields'] = fields
    return corpo


def _primeiro(valor):
    """`["msg"]` → `"msg"`. Serializer embrulha em lista o que é levantado no
    validate(); o contrato quer o valor solto."""
    while isinstance(valor, (list, tuple)) and valor:
        valor = valor[0]
    return valor


def _validacao(detalhe, codigos) -> dict:
    if isinstance(detalhe, dict):
        detalhe = dict(detalhe)
        codigos = codigos if isinstance(codigos, dict) else {}
        # Erro de regra levantado como ValidationError({'detail': ..., 'code': ...}).
        if 'detail' in detalhe:
            mensagem = _primeiro(detalhe.pop('detail'))
            codigo = _primeiro(detalhe.pop('code', None)) or _primeiro(codigos.get('detail'))
            return corpo_de_erro(mensagem, _mapear_codigo(str(codigo or ''), 400), fields=detalhe or None)
        nao_de_campo = detalhe.pop('non_field_errors', None)
        mensagem = _primeiro(nao_de_campo) if nao_de_campo else 'Dados inválidos.'
        codigo = _primeiro(codigos.get('non_field_errors')) if nao_de_campo else None
        return corpo_de_erro(mensagem, _mapear_codigo(str(codigo or ''), 400), fields=detalhe or None)
    # Lista de mensagens sem campo.
    return corpo_de_erro(_primeiro(detalhe) or 'Dados inválidos.', _mapear_codigo(str(_primeiro(codigos) or ''), 400))


def tratar_excecao(exc, context):
    if isinstance(exc, ErroDeNegocio):
        return Response(corpo_de_erro(exc.detail, exc.code, exc.status_code), status=exc.status_code)

    if isinstance(exc, Http404):
        exc = exceptions.NotFound()
    elif isinstance(exc, DjangoPermissionDenied):
        exc = exceptions.PermissionDenied()

    response = exception_handler(exc, context)
    if response is None:
        return None  # erro não tratado: o Django responde 500

    if isinstance(exc, exceptions.ValidationError):
        response.data = _validacao(exc.detail, exc.get_codes())
    elif isinstance(exc, exceptions.APIException):
        codigo = exc.get_codes()
        if isinstance(exc.detail, dict):
            # Ex.: AuthenticationFailed do SimpleJWT, que manda {detail, code, messages}.
            mensagem = _primeiro(exc.detail.get('detail', '')) or exc.default_detail
            codigo = _primeiro(exc.detail.get('code')) or _primeiro(codigo.get('detail') if isinstance(codigo, dict) else None)
        else:
            mensagem = _primeiro(exc.detail)
            codigo = _primeiro(codigo)
        response.data = corpo_de_erro(mensagem, _mapear_codigo(str(codigo or ''), response.status_code), response.status_code)
    return response


# Códigos padrão do DRF/SimpleJWT, traduzidos para o padrão do projeto.
_CODIGOS_DRF = {
    'invalid': 'invalido',
    'not_authenticated': 'nao_autenticado',
    'authentication_failed': 'nao_autenticado',
    'permission_denied': 'sem_permissao',
    'not_found': 'nao_encontrado',
    'method_not_allowed': 'metodo_nao_permitido',
    'throttled': 'muitas_requisicoes',
    'parse_error': 'requisicao_malformada',
    'unsupported_media_type': 'tipo_nao_suportado',
    'not_acceptable': 'formato_nao_aceito',
    'token_not_valid': 'token_invalido',
    'user_not_found': 'nao_autenticado',
    'user_inactive': 'conta_inativa',
    'password_changed': 'sessao_encerrada',
}


def _mapear_codigo(codigo: str, status_code: int) -> str:
    if not codigo or codigo == 'error':
        return _CODIGO_POR_STATUS.get(status_code, 'erro')
    return _CODIGOS_DRF.get(codigo, codigo)
