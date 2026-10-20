"""Links públicos que saem do backend (e-mails e redirects).

Todo link que uma pessoa abre fora da API nasce aqui, sobre um único
LINKS_BASE_URL. O app mobile captura esses mesmos caminhos como App Link
(Android) / Universal Link (iOS), então o formato é contrato com o front:
mudar um caminho quebra o link no app.

- /convite/<token>                abre no app do Work Manage (colaborador)
- /contrato/<schema>/<token>      página web de assinatura (cliente da empresa,
                                  que não tem o app)
- /app/pagamentos?<query>         volta do checkout da assinatura
"""
from django.conf import settings


def _base() -> str:
    return settings.LINKS_BASE_URL.rstrip('/')


def link_convite(token) -> str:
    return f'{_base()}/convite/{token}'


def link_contrato(schema_name: str, token) -> str:
    return f'{_base()}/contrato/{schema_name}/{token}'


def link_retorno_pagamento(query: str = '') -> str:
    return f'{_base()}/app/pagamentos' + (f'?{query}' if query else '')
