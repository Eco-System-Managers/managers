from django.db import connection
from rest_framework.permissions import BasePermission

from core.excecoes import ErroDeNegocio
from tenants.models import Membro, Papel


def eh_proprietario(request) -> bool:
    """O papel vem do Membro, a fonte única. A TenantJWTAuthentication já o
    deixa no usuário; a consulta cobre quem chega por outro caminho.

    Sem vínculo com o tenant atual, não é dono. Antes, usuário sem Colaborador
    era tratado como dono (onboarding) — e isso valia também para quem nem
    pertencia ao tenant.
    """
    if hasattr(request.user, 'papel_no_tenant'):
        papel = request.user.papel_no_tenant
    else:
        papel = Membro.papel_no_schema(request.user, connection.schema_name)
    return papel == Papel.PROPRIETARIO


def colaborador_do(request):
    """O Colaborador do usuário logado, lido do banco a cada chamada.

    Não usa `request.user.colaborador`: o acessor fica em cache no objeto do
    usuário, e uma flag trocada no meio do caminho continuaria valendo a antiga.
    """
    from apps_work.usuarios.models import Colaborador

    return Colaborador.objects.filter(user_id=request.user.pk).first()


def colaborador_aplicado(request, pedido: int | None) -> int | None:
    """O colaborador a aplicar num filtro de números (painel, caixa).

    O proprietário vê o que pediu (ou todos). Quem não é vê só os próprios
    números, seja o que for que veio na query: a trava fica aqui, não na tela,
    senão bastaria trocar o parâmetro. Sem perfil de colaborador, 404.
    """
    if eh_proprietario(request):
        return pedido
    colaborador = colaborador_do(request)
    if colaborador is None:
        raise ErroDeNegocio('Usuário sem perfil de colaborador.', 'sem_colaborador', 404)
    return colaborador.id


def vinculo_do_usuario(request) -> str:
    """'proprietario', 'parceiro' ou 'colaborador' — o que decide o que a pessoa vê.

    Sem perfil de colaborador, é tratado como colaborador comum: o menor acesso.
    """
    from apps_work.usuarios.models import VinculoColaborador

    if eh_proprietario(request):
        return 'proprietario'
    colaborador = colaborador_do(request)
    return colaborador.tipo if colaborador else VinculoColaborador.COLABORADOR


def ve_valores(request) -> bool:
    """Dono e parceiro veem dinheiro; o colaborador comum não."""
    return vinculo_do_usuario(request) != 'colaborador'


def exigir_ver_valores(request) -> None:
    if not ve_valores(request):
        raise ErroDeNegocio('Você não tem acesso aos valores.', 'sem_acesso_a_valores', 403)


def exigir_poder_cobrar(request) -> None:
    """Dono e parceiro cobram sempre; o colaborador comum só com a flag ligada."""
    if eh_proprietario(request):
        return
    colaborador = colaborador_do(request)
    if colaborador is None:
        raise ErroDeNegocio('Usuário sem perfil de colaborador.', 'sem_colaborador', 404)
    if not colaborador.eh_parceiro and not colaborador.pode_cobrar:
        raise ErroDeNegocio('Você não pode registrar cobranças.', 'sem_permissao_cobrar', 403)


class IsProprietario(BasePermission):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return eh_proprietario(request)
