"""Formato dos links públicos: é contrato com o app (App Link/Universal Link)."""
from core.links import link_contrato, link_convite, link_retorno_pagamento


def test_convite(settings):
    settings.LINKS_BASE_URL = 'https://app.exemplo.com.br/'
    assert link_convite('abc') == 'https://app.exemplo.com.br/convite/abc'


def test_contrato(settings):
    settings.LINKS_BASE_URL = 'https://app.exemplo.com.br'
    assert link_contrato('barbearia', 'xyz') == 'https://app.exemplo.com.br/contrato/barbearia/xyz'


def test_retorno_pagamento_com_e_sem_query(settings):
    settings.LINKS_BASE_URL = 'https://app.exemplo.com.br'
    assert link_retorno_pagamento() == 'https://app.exemplo.com.br/app/pagamentos'
    assert link_retorno_pagamento('a=1') == 'https://app.exemplo.com.br/app/pagamentos?a=1'
