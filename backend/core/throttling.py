import hashlib

from rest_framework.throttling import SimpleRateThrottle, UserRateThrottle


class UsuarioRateThrottle(UserRateThrottle):
    """Limite por conta logada, com o produto na chave.

    O UserRateThrottle do DRF usa só `request.user.pk`: o User 5 do Work Manage
    e o Consumidor 5 do Service Manage dividiriam o mesmo contador. Anônimo
    fica com o AnonRateThrottle (por IP).
    """

    def get_cache_key(self, request, view):
        user = request.user
        if not (user and user.is_authenticated):
            return None
        ident = f'{type(user).__name__.lower()}:{user.pk}'
        return self.cache_format % {'scope': self.scope, 'ident': ident}


class _EmailRateThrottle(SimpleRateThrottle):
    """Limite pelo e-mail enviado no corpo, independente do IP.

    O e-mail entra na chave como hash, para não ficar em claro no cache.
    """

    def get_cache_key(self, request, view):
        email = str(request.data.get('email', '')).strip().lower()
        if not email:
            return None
        ident = hashlib.sha256(email.encode()).hexdigest()
        return self.cache_format % {'scope': self.scope, 'ident': ident}


class RecuperacaoPorEmailThrottle(_EmailRateThrottle):
    """Quantos códigos de recuperação um e-mail do Work Manage recebe por hora."""
    scope = 'recuperacao_email'


class RecuperacaoConsumidorPorEmailThrottle(_EmailRateThrottle):
    """Quantos códigos de recuperação um e-mail do Service Manage recebe por hora."""
    scope = 'sm_recuperacao_email'
