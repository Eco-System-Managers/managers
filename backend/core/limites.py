import hashlib

from django.core.cache import cache
from rest_framework import status

from core.excecoes import ErroDeNegocio


class MuitasTentativas(ErroDeNegocio):
    """Limite de falhas atingido para a conta; vale até a janela passar.

    É um ErroDeNegocio com status 429: o handler já monta a resposta, sem a
    view precisar capturar.
    """

    def __init__(self):
        super().__init__(
            'Muitas tentativas. Aguarde alguns minutos e tente novamente.',
            'muitas_tentativas',
            status.HTTP_429_TOO_MANY_REQUESTS,
        )


class LimiteDeFalhas:
    """Conta falhas por conta (e-mail) numa janela fixa, e só falhas.

    Um throttle comum por e-mail contaria toda tentativa, e qualquer pessoa
    travaria o login de outra mandando senhas erradas. Aqui o acerto zera a
    contagem, e a janela começa na primeira falha. A chave vale para qualquer
    e-mail, exista ou não a conta — senão o bloqueio revelaria quem tem conta.
    """

    def __init__(self, escopo: str, maximo: int = 10, janela_segundos: int = 15 * 60):
        self.escopo = escopo
        self.maximo = maximo
        self.janela_segundos = janela_segundos

    def _chave(self, email: str) -> str:
        ident = hashlib.sha256(email.strip().lower().encode()).hexdigest()
        return f'falhas:{self.escopo}:{ident}'

    def verificar(self, email: str) -> None:
        if cache.get(self._chave(email), 0) >= self.maximo:
            raise MuitasTentativas()

    def registrar_falha(self, email: str) -> None:
        chave = self._chave(email)
        # add só grava se a chave não existe: é ele que abre a janela.
        if not cache.add(chave, 1, self.janela_segundos):
            try:
                cache.incr(chave)
            except ValueError:
                # Expirou entre o add e o incr.
                cache.add(chave, 1, self.janela_segundos)

    def limpar(self, email: str) -> None:
        cache.delete(self._chave(email))


login_work = LimiteDeFalhas('login_work')
login_servicemanage = LimiteDeFalhas('login_servicemanage')
