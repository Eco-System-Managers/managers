from datetime import datetime, timedelta, timezone as dt_timezone

import jwt
from django.conf import settings
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed

from apps_serv.consumidores.models import Consumidor

_ACCESS_LIFETIME = timedelta(minutes=60)
_REFRESH_LIFETIME = timedelta(days=7)
_ALGORITHM = 'HS256'
_ACCESS_TYPE = 'consumidor_access'
_REFRESH_TYPE = 'consumidor_refresh'


def gerar_tokens(consumidor: Consumidor) -> tuple[str, str]:
    now = datetime.now(dt_timezone.utc)
    access = jwt.encode(
        {
            'type': _ACCESS_TYPE,
            'consumidor_id': consumidor.id,
            'nome': consumidor.nome,
            'exp': now + _ACCESS_LIFETIME,
            'iat': now,
        },
        settings.SECRET_KEY,
        algorithm=_ALGORITHM,
    )
    refresh = jwt.encode(
        {
            'type': _REFRESH_TYPE,
            'consumidor_id': consumidor.id,
            'exp': now + _REFRESH_LIFETIME,
            'iat': now,
        },
        settings.SECRET_KEY,
        algorithm=_ALGORITHM,
    )
    return access, refresh


def renovar_access_token(refresh_token_str: str) -> tuple[str, Consumidor]:
    try:
        payload = jwt.decode(refresh_token_str, settings.SECRET_KEY, algorithms=[_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise AuthenticationFailed('Sessão expirada. Faça login novamente.')
    except jwt.InvalidTokenError:
        raise AuthenticationFailed('Token inválido.')

    if payload.get('type') != _REFRESH_TYPE:
        raise AuthenticationFailed('Token inválido.')

    try:
        consumidor = Consumidor.objects.get(id=payload['consumidor_id'], is_active=True)
    except Consumidor.DoesNotExist:
        raise AuthenticationFailed('Conta não encontrada.')

    now = datetime.now(dt_timezone.utc)
    access = jwt.encode(
        {
            'type': _ACCESS_TYPE,
            'consumidor_id': consumidor.id,
            'nome': consumidor.nome,
            'exp': now + _ACCESS_LIFETIME,
            'iat': now,
        },
        settings.SECRET_KEY,
        algorithm=_ALGORITHM,
    )
    return access, consumidor


class ConsumidorJWTAuthentication(BaseAuthentication):
    def authenticate_header(self, request):
        # Without this, DRF returns 403 instead of 401 for unauthenticated requests.
        return 'Bearer realm="api"'

    def authenticate(self, request):
        header = request.headers.get('Authorization', '')
        if not header.startswith('Bearer '):
            return None

        token_str = header.split(' ', 1)[1]
        try:
            payload = jwt.decode(token_str, settings.SECRET_KEY, algorithms=[_ALGORITHM])
        except jwt.ExpiredSignatureError:
            raise AuthenticationFailed('Token expirado.')
        except jwt.InvalidTokenError:
            raise AuthenticationFailed('Token inválido.')

        if payload.get('type') != _ACCESS_TYPE:
            return None

        try:
            consumidor = Consumidor.objects.get(id=payload['consumidor_id'], is_active=True)
        except Consumidor.DoesNotExist:
            raise AuthenticationFailed('Conta não encontrada.')

        return (consumidor, token_str)
