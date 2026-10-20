from rest_framework.pagination import PageNumberPagination


class Paginacao(PageNumberPagination):
    """Paginação padrão de toda coleção de recurso da API.

    Formato: `{count, next, previous, results}`. `?page=` escolhe a página e
    `?page_size=` o tamanho, até `max_page_size` — a agenda de um dia, por
    exemplo, pede `page_size=100` para vir inteira numa página só.

    Listas calculadas ou de tamanho fixo (slots, horários da semana, cidades,
    nichos) não usam paginação: são arrays, tipados no schema OpenAPI.
    """

    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100


def resposta_paginada(request, itens, view=None, serializar=None):
    """Pagina uma lista ou queryset numa APIView, no mesmo formato dos viewsets.

    `serializar` recebe só a página — assim o trabalho caro (serializer,
    consultas extras) é feito para 20 itens, não para a coleção inteira.
    """
    paginador = Paginacao()
    pagina = paginador.paginate_queryset(itens, request, view=view)
    return paginador.get_paginated_response(serializar(pagina) if serializar else pagina)
