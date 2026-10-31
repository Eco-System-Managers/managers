from core.excecoes import ErroDeNegocio

from .models import Servico


def servicos_ativos(ids: list[int]) -> list[Servico]:
    """Os serviços destes ids, na ordem pedida e sem repetição.

    Id que não existe ou serviço inativo é 400 `servico_invalido`: quem manda
    a lista (a troca de serviço na cobrança) só pode escolher o que está no
    catálogo agora. Um erro para a lista toda, e não por item: o app já mostra
    só os ativos, então o que chega errado foi montado à mão.
    """
    por_id = Servico.objects.in_bulk(ids)
    if any(i not in por_id or not por_id[i].ativo for i in ids):
        raise ErroDeNegocio('Serviço não encontrado ou inativo.', 'servico_invalido')
    return [por_id[i] for i in dict.fromkeys(ids)]


def conferir_porte(
    servico: Servico, porte: str, *, o_que_fazer: str = 'Escolha outro serviço ou corrija o porte no cadastro.',
) -> None:
    """Serviço de um porte só atende esse porte (`servico_de_outro_porte`).

    A tela já mostra só os serviços que servem; esta é a trava para o que
    chega montado à mão. `o_que_fazer` muda com quem pediu: o negócio pode
    corrigir o cadastro, o cliente do app só pode escolher outro serviço.
    """
    if servico.serve_para(porte):
        return
    raise ErroDeNegocio(
        f'Este serviço é só para o porte {servico.get_porte_display()}. {o_que_fazer}',
        'servico_de_outro_porte',
    )
