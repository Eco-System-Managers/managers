"""Quais requisições viram evento de uso, e com que nome.

O evento sai do nome da rota, que a API já tem, e não de uma chamada em cada
service: uma rota nova entra sozinha. O nome segue o recurso e a ação:

- rota de coleção do router (`agendamento-list`): POST é `agendamento.criar`
- rota de item (`agendamento-detail`): PUT/PATCH é `.editar`, DELETE é `.remover`
- as outras (`agendamento-cobrar`, `auth-login`): o nome da rota no POST, e
  com o método nos demais (`kanban-capacidade.put`)

O que entra: toda escrita, todo erro e a abertura do app (`app.aberto`, o
`colaboradores/me/` que a casca do app chama ao entrar). As leituras de
sucesso ficam de fora: são a maior parte do tráfego e dizem pouco.
"""
import logging

from django.db import transaction

from .models import EventoDeUso

logger = logging.getLogger(__name__)

APP_ABERTO = 'app.aberto'

_ESCRITA = {'POST', 'PUT', 'PATCH', 'DELETE'}
# A renovação da sessão (o refresh e o 401 que a provoca) é o app fazendo o
# trabalho dele, não uma ação de quem usa; o schema é o próprio cliente.
_ROTAS_IGNORADAS = {'auth-token-refresh', 'schema-work', 'api-root'}
_CODIGOS_IGNORADOS = {'token_invalido'}

_ACAO_NA_COLECAO = {'GET': 'listar', 'POST': 'criar'}
_ACAO_NO_ITEM = {'GET': 'ver', 'PUT': 'editar', 'PATCH': 'editar', 'DELETE': 'remover'}


def nome_do_evento(rota: str, metodo: str) -> str:
    if rota == 'colaborador-me' and metodo == 'GET':
        return APP_ABERTO
    recurso, _, sufixo = rota.rpartition('-')
    if sufixo == 'list':
        return f'{recurso}.{_ACAO_NA_COLECAO.get(metodo, metodo.lower())}'
    if sufixo == 'detail':
        return f'{recurso}.{_ACAO_NO_ITEM.get(metodo, metodo.lower())}'
    return rota if metodo == 'POST' else f'{rota}.{metodo.lower()}'


def deve_registrar(rota: str, metodo: str, status: int, codigo: str) -> bool:
    # Sem rota é endereço que não existe (robôs procurando falha).
    if not rota or rota in _ROTAS_IGNORADAS or codigo in _CODIGOS_IGNORADOS:
        return False
    if metodo in _ESCRITA:
        return True
    if metodo == 'GET':
        return status >= 400 or (rota == 'colaborador-me' and status < 300)
    return False


def registrar(dados: dict) -> None:
    """Grava o evento da requisição, a partir do retrato de `core/requisicao.py`.

    Num savepoint: uma falha aqui não pode envenenar a transação de quem
    chamou. E nunca levanta.
    """
    if not deve_registrar(dados['rota'], dados['metodo'], dados['status'], dados['codigo']):
        return
    try:
        with transaction.atomic():
            EventoDeUso.objects.create(
                schema_name=dados['schema_name'],
                user_id=dados['user_id'],
                papel=dados['papel'],
                evento=nome_do_evento(dados['rota'], dados['metodo']),
                metodo=dados['metodo'],
                objeto_id=dados['objeto_id'],
                status=dados['status'],
                codigo=dados['codigo'],
                duracao_ms=dados['duracao_ms'],
                plataforma=dados['plataforma'],
                versao_app=dados['versao_app'],
            )
    except Exception:
        logger.warning('Falha ao gravar o evento de uso', exc_info=True)
