"""Chaves de cache compartilhadas entre quem le e quem invalida.

Existe para a chave nao ficar escrita em dois lugares: o middleware que le o
estado da assinatura e o model que a invalida ao salvar. Duplicar o formato
aqui significaria invalidar uma chave que ninguem le — uma falha silenciosa,
que so aparece como cliente que pagou e continua bloqueado.
"""

from django.core.cache import cache

# Curto de proposito. `Assinatura.bloqueada` depende de `date.today()`, entao um
# trial que vence a meia-noite precisa passar a bloquear sozinho, sem depender de
# ninguem salvar nada. A liberacao apos pagamento nao espera esse prazo: o save()
# da Assinatura limpa a chave na hora.
TTL_ASSINATURA_SEGUNDOS = 60


def chave_assinatura_bloqueada(schema_name: str) -> str:
    return f'assinatura_bloqueada:{schema_name}'


def invalidar_assinatura(schema_name: str) -> None:
    cache.delete(chave_assinatura_bloqueada(schema_name))
