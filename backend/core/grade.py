"""A grade de horários dos dois modos de agenda.

De 15 em 15 minutos, um início só entra se o atendimento inteiro couber: antes
do fechamento e sem passar de quantos cabem ao mesmo tempo. Sem banco: quem
chama monta o expediente e as ocupações. Na agenda, a ocupação é a do
profissional e cabe um por vez; na esteira, é a do negócio inteiro, e cabem
tantos quantas forem as vagas do dia.
"""
from datetime import datetime, timedelta

PASSO_MINUTOS = 15

Intervalo = tuple[datetime, datetime]


def proxima_marca(momento: datetime) -> datetime:
    """O `momento` arredondado para cima até a marca de 15 minutos: 10:37:12
    vira 10:45. É o que a grade oferece quando "agora" entra na conta: um
    início com segundos não é hora de ninguém."""
    base = momento.replace(second=0, microsecond=0)
    if base != momento:
        base += timedelta(minutes=1)
    resto = base.minute % PASSO_MINUTOS
    if resto:
        base += timedelta(minutes=PASSO_MINUTOS - resto)
    return base


def inicios_livres(
    abertura: datetime,
    fechamento: datetime,
    duracao: timedelta,
    ocupados: list[Intervalo],
    vagas: int = 1,
    nao_antes_de: datetime | None = None,
) -> list[datetime]:
    """Os inícios livres, em ordem, no horário local e sem fuso.

    Candidatos: a grade de 15 em 15 minutos a partir da abertura e, além dela,
    o fim de cada ocupação — acabou um às 9:20, o 9:20 é oferecido, sem esperar
    o 9:30. `nao_antes_de` é a antecedência de quem pede.
    """
    candidatos = set()
    atual = abertura
    while atual + duracao <= fechamento:
        candidatos.add(atual)
        atual += timedelta(minutes=PASSO_MINUTOS)
    for _, fim in ocupados:
        if abertura <= fim and fim + duracao <= fechamento:
            candidatos.add(fim)

    return [
        inicio for inicio in sorted(candidatos)
        if (nao_antes_de is None or inicio >= nao_antes_de) and cabe(inicio, inicio + duracao, ocupados, vagas)
    ]


def cabe(inicio: datetime, fim: datetime, ocupados: list[Intervalo], vagas: int = 1) -> bool:
    """Se [inicio, fim) tem vaga: em nenhum momento dele há `vagas` ocupações
    ao mesmo tempo. O pico, se houver, acontece no começo de alguma delas."""
    sobrepostos = [(max(i, inicio), min(f, fim)) for i, f in ocupados if i < fim and inicio < f]
    if len(sobrepostos) < vagas:
        return True
    return all(
        sum(1 for i, f in sobrepostos if i <= ponto < f) < vagas
        for ponto in {inicio} | {i for i, _ in sobrepostos}
    )
