"""Como os tokens de sessão chegam ao cliente, nos dois produtos.

O web guarda o refresh só no cookie httpOnly, fora do alcance de JavaScript.
O app mobile não tem cookie de navegador: ele se identifica pelo cabeçalho
`X-Client-Platform: mobile` e recebe e envia o refresh no corpo.
"""
from dataclasses import dataclass

from django.conf import settings

from core import rotas

CABECALHO_PLATAFORMA = 'X-Client-Platform'


def cliente_mobile(request) -> bool:
    return request.headers.get(CABECALHO_PLATAFORMA, '').strip().lower() == 'mobile'


@dataclass(frozen=True)
class CookieDeRefresh:
    """O cookie httpOnly do refresh de um produto.

    Cada produto tem o seu nome e fica restrito às rotas de autenticação dele
    (`path`), para o navegador não mandá-lo em nenhuma outra requisição.
    """
    nome: str
    caminho: str
    config_jwt: str  # nome do dict de settings com o REFRESH_TOKEN_LIFETIME

    def definir(self, response, token: str) -> None:
        validade = getattr(settings, self.config_jwt)['REFRESH_TOKEN_LIFETIME']
        response.set_cookie(
            key=self.nome,
            value=token,
            httponly=True,
            secure=not settings.DEBUG,
            samesite='Lax',
            max_age=int(validade.total_seconds()),
            path=self.caminho,
        )

    def apagar(self, response) -> None:
        response.delete_cookie(key=self.nome, path=self.caminho)

    def refresh_da_requisicao(self, request) -> str:
        """O refresh enviado pelo cliente: corpo no mobile, cookie no web."""
        if cliente_mobile(request):
            return request.data.get('refresh', '') or ''
        return request.COOKIES.get(self.nome, '')

    def entregar(self, request, response, refresh: str) -> None:
        """Põe o refresh no corpo (mobile) ou no cookie (web) — nunca nos dois."""
        if cliente_mobile(request):
            response.data['refresh'] = refresh
        else:
            self.definir(response, refresh)


COOKIE_WORK = CookieDeRefresh('refresh_token', rotas.WORK_AUTH, 'SIMPLE_JWT')
COOKIE_SERVICEMANAGE = CookieDeRefresh('sm_refresh_token', rotas.SERVICEMANAGE_AUTH, 'SERVICEMANAGE_JWT')
