"""Como os tokens de sessão chegam ao cliente, nos dois produtos.

O web guarda o refresh só no cookie httpOnly, fora do alcance de JavaScript.
O app mobile não tem cookie de navegador: ele se identifica pelo cabeçalho
`X-Client-Platform: mobile` e recebe e envia o refresh no corpo.
"""

CABECALHO_PLATAFORMA = 'X-Client-Platform'


def cliente_mobile(request) -> bool:
    return request.headers.get(CABECALHO_PLATAFORMA, '').strip().lower() == 'mobile'


def refresh_da_requisicao(request, cookie: str) -> str:
    """O refresh enviado pelo cliente: corpo no mobile, cookie no web."""
    if cliente_mobile(request):
        return request.data.get('refresh', '') or ''
    return request.COOKIES.get(cookie, '')


def entregar_refresh(request, response, refresh: str, definir_cookie) -> None:
    """Põe o refresh no corpo (mobile) ou no cookie (web) — nunca nos dois."""
    if cliente_mobile(request):
        response.data['refresh'] = refresh
    else:
        definir_cookie(response, refresh)
