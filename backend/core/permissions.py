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


def colaborador_aplicado(request, pedido: int | None) -> int | None:
    """O colaborador a aplicar num filtro de números (painel, caixa).

    O proprietário vê o que pediu (ou todos). Quem não é vê só os próprios
    números, seja o que for que veio na query: a trava fica aqui, não na tela,
    senão bastaria trocar o parâmetro. Sem perfil de colaborador, 404.
    """
    from apps_work.usuarios.models import Colaborador

    if eh_proprietario(request):
        return pedido
    try:
        return request.user.colaborador.id
    except Colaborador.DoesNotExist:
        raise ErroDeNegocio('Usuário sem perfil de colaborador.', 'sem_colaborador', 404)


class IsProprietario(BasePermission):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return eh_proprietario(request)
