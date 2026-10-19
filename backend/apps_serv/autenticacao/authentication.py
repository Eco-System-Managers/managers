import uuid
from datetime import datetime, timezone as dt_timezone

import jwt
from django.conf import settings
from django.db import IntegrityError, transaction
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed

from apps_serv.consumidores.models import Consumidor, RefreshRevogadoConsumidor

_ALGORITHM = 'HS256'
_ACCESS_TYPE = 'consumidor_access'
_REFRESH_TYPE = 'consumidor_refresh'


def _config(chave: str):
    return settings.SERVICEMANAGE_JWT[chave]


def _emitir(consumidor: Consumidor, tipo: str, validade, **extra) -> str:
    agora = datetime.now(dt_timezone.utc)
    return jwt.encode(
        {
            'type': tipo,
            'consumidor_id': consumidor.id,
            'jti': uuid.uuid4().hex,
            'iss': _config('ISSUER'),
            'aud': _config('AUDIENCE'),
            'iat': agora,
            'exp': agora + validade,
            **extra,
        },
        _config('SIGNING_KEY'),
        algorithm=_ALGORITHM,
    )


def _decodificar(token_str: str) -> dict:
    """Valida assinatura, expiração, emissor e audiência. Token do Work Manage
    é recusado aqui: tem outra chave, outro emissor e outra audiência."""
    try:
        return jwt.decode(
            token_str,
            _config('SIGNING_KEY'),
            algorithms=[_ALGORITHM],
            audience=_config('AUDIENCE'),
            issuer=_config('ISSUER'),
            options={'require': ['exp', 'iat', 'jti', 'iss', 'aud']},
        )
    except jwt.ExpiredSignatureError:
        raise AuthenticationFailed('Sessão expirada. Faça login novamente.')
    except jwt.InvalidTokenError:
        raise AuthenticationFailed('Token inválido.')


def _sessao_valida(consumidor: Consumidor, payload: dict) -> bool:
    """Token emitido antes da última troca de senha não vale mais."""
    desde = consumidor.sessoes_validas_desde
    return desde is None or payload['iat'] >= int(desde.timestamp())


def _consumidor_do_token(payload: dict) -> Consumidor:
    try:
        consumidor = Consumidor.objects.get(id=payload['consumidor_id'], is_active=True)
    except Consumidor.DoesNotExist:
        raise AuthenticationFailed('Conta não encontrada.')
    if not _sessao_valida(consumidor, payload):
        raise AuthenticationFailed('Sessão encerrada. Faça login novamente.')
    return consumidor


def _revogar(payload: dict) -> bool:
    """Marca o refresh como usado. Devolve False se ele já estava revogado —
    o unique do jti garante que duas renovações simultâneas não passam."""
    try:
        with transaction.atomic():
            RefreshRevogadoConsumidor.objects.create(
                jti=payload['jti'],
                expira_em=datetime.fromtimestamp(payload['exp'], tz=dt_timezone.utc),
            )
        return True
    except IntegrityError:
        return False


def gerar_tokens(consumidor: Consumidor) -> tuple[str, str]:
    access = _emitir(
        consumidor, _ACCESS_TYPE, _config('ACCESS_TOKEN_LIFETIME'), nome=consumidor.nome,
    )
    refresh = _emitir(consumidor, _REFRESH_TYPE, _config('REFRESH_TOKEN_LIFETIME'))
    return access, refresh


def renovar_tokens(refresh_token_str: str) -> tuple[str, str, Consumidor]:
    """Troca um refresh por um novo par. O refresh usado é revogado: cada um
    vale uma única vez."""
    payload = _decodificar(refresh_token_str)
    if payload.get('type') != _REFRESH_TYPE:
        raise AuthenticationFailed('Token inválido.')

    consumidor = _consumidor_do_token(payload)
    if not _revogar(payload):
        raise AuthenticationFailed('Sessão expirada. Faça login novamente.')

    access, refresh = gerar_tokens(consumidor)
    return access, refresh, consumidor


def revogar_refresh(refresh_token_str: str) -> None:
    """Logout. Token inválido, expirado ou já revogado é ignorado."""
    try:
        payload = _decodificar(refresh_token_str)
    except AuthenticationFailed:
        return
    if payload.get('type') == _REFRESH_TYPE:
        _revogar(payload)


class ConsumidorJWTAuthentication(BaseAuthentication):
    def authenticate_header(self, request):
        # Without this, DRF returns 403 instead of 401 for unauthenticated requests.
        return 'Bearer realm="api"'

    def authenticate(self, request):
        header = request.headers.get('Authorization', '')
        if not header.startswith('Bearer '):
            return None

        token_str = header.split(' ', 1)[1]
        payload = _decodificar(token_str)

        if payload.get('type') != _ACCESS_TYPE:
            return None

        return (_consumidor_do_token(payload), token_str)
