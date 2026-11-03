"""O retrato de uma requisição da API depois de respondida.

O `RequisicaoMiddleware` monta o retrato uma vez e o usa duas vezes: a linha
do log (todas as requisições da API) e o evento de uso do Work Manage
(`apps_work/uso`, só o que importa para acompanhar os testadores).

Só entra o que descreve a ação, nunca o conteúdo: nem o corpo, nem a query
string (a busca de clientes manda nome e telefone por ela), nem os tokens dos
links de convite e de contrato, que valem como senha.
"""
import json
import logging

from django.db import connection
from django.utils.functional import SimpleLazyObject
from rest_framework_simplejwt.tokens import AccessToken

from core.sessao import cliente_mobile

logger = logging.getLogger('workmanage.requisicao')

CABECALHO_VERSAO = 'X-App-Version'

# Argumentos da URL que identificam o objeto da ação.
_ARGUMENTOS_DE_OBJETO = ('pk', 'cliente_id', 'agendamento_id', 'objeto_id')
# Argumentos da URL que não podem ir para o log.
_ARGUMENTOS_SECRETOS = ('token',)


def retrato(request, response, duracao_ms: int) -> dict:
    match = getattr(request, 'resolver_match', None)
    argumentos = match.kwargs if match else {}
    user_id, papel, schema_name = _quem(request, response)
    return {
        'metodo': request.method,
        'caminho': _caminho_sem_segredo(request.path, argumentos),
        'rota': (match.url_name or '') if match else '',
        'objeto_id': next((str(argumentos[a]) for a in _ARGUMENTOS_DE_OBJETO if a in argumentos), ''),
        'status': response.status_code,
        'codigo': _codigo_do_erro(response),
        'duracao_ms': duracao_ms,
        'schema_name': schema_name,
        'user_id': user_id,
        'papel': papel,
        'plataforma': 'mobile' if cliente_mobile(request) else 'web',
        'versao_app': request.headers.get(CABECALHO_VERSAO, '')[:30],
    }


def logar(dados: dict) -> None:
    status = dados['status']
    nivel = logging.ERROR if status >= 500 else logging.WARNING if status >= 400 else logging.INFO
    mensagem = f"{dados['metodo']} {dados['caminho']} {status} {dados['duracao_ms']}ms"
    logger.log(nivel, mensagem, extra={'dados': dados})


def _caminho_sem_segredo(caminho: str, argumentos: dict) -> str:
    for nome in _ARGUMENTOS_SECRETOS:
        if argumentos.get(nome):
            caminho = caminho.replace(str(argumentos[nome]), f':{nome}')
    return caminho


def _quem(request, response) -> tuple[int | None, str, str]:
    """Usuário, papel e schema de quem fez a requisição.

    Na ordem: o usuário que o DRF autenticou (com o papel que a autenticação
    já encontrou), o token do cabeçalho (as respostas dos middlewares, como o
    402, saem antes do DRF) e o token que a própria resposta entrega (login,
    confirmação do cadastro, aceite do convite).
    """
    from core.middleware import _token_do_request

    user_id, papel = None, ''
    # Só o usuário que o DRF pôs no request. O preguiçoso do
    # AuthenticationMiddleware, avaliado aqui, iria buscar a sessão no banco.
    user = request.__dict__.get('user')
    if user is not None and type(user) is not SimpleLazyObject and user.is_authenticated:
        user_id, papel = user.pk, getattr(user, 'papel_no_tenant', '') or ''

    token = _token_do_request(request) or _token_da_resposta(response)
    if user_id is None and token is not None:
        # O SimpleJWT grava o id como texto.
        try:
            user_id = int(token.get('user_id'))
        except (TypeError, ValueError):
            user_id = None

    schema_name = (token.get('schema_name') if token is not None else '') or ''
    if not schema_name and connection.schema_name != 'public':
        schema_name = connection.schema_name
    return user_id, papel, schema_name


def _token_da_resposta(response):
    dados = getattr(response, 'data', None)
    if response.status_code >= 400 or not isinstance(dados, dict) or not dados.get('access'):
        return None
    try:
        return AccessToken(dados['access'])
    except Exception:
        return None


def _codigo_do_erro(response) -> str:
    """O `code` do contrato de erro. Vem do DRF ou de um JsonResponse dos
    middlewares (o 402 e o 401 de inatividade)."""
    if response.status_code < 400:
        return ''
    dados = getattr(response, 'data', None)
    if dados is None and response.get('Content-Type', '').startswith('application/json'):
        try:
            dados = json.loads(response.content)
        except ValueError:
            dados = None
    if isinstance(dados, dict):
        return str(dados.get('code') or '')[:60]
    return ''
