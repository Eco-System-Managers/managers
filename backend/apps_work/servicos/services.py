from core.excecoes import ErroDeNegocio

from .models import Servico


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
