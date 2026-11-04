from rest_framework.permissions import BasePermission

from core.excecoes import ErroDeNegocio
from core.tenant import schema_atual
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
        papel = Membro.papel_no_schema(request.user, schema_atual())
    return papel == Papel.PROPRIETARIO


def colaborador_do(request):
    """O Colaborador do usuário logado, lido do banco a cada chamada.

    Não usa `request.user.colaborador`: o acessor fica em cache no objeto do
    usuário, e uma flag trocada no meio do caminho continuaria valendo a antiga.
    """
    from apps_work.usuarios.models import Colaborador

    return Colaborador.objects.filter(user_id=request.user.pk).first()


def eh_esteira(request=None) -> bool:
    """O negócio atual é do modo esteira (`EmpresaConfig.tipo_agenda`).

    Na esteira a operação é do negócio inteiro: a fila e o caixa são de todos,
    e o vínculo (parceiro, colaborador) diz o que cada um pode, não de quem é
    o atendimento. O modo não muda depois do onboarding. Com `request`, a
    resposta fica guardada nela: a mesma requisição não consulta duas vezes.
    """
    from apps_work.empresa.models import EmpresaConfig, TipoAgenda

    if request is not None and hasattr(request, '_eh_esteira'):
        return request._eh_esteira
    tipo = EmpresaConfig.objects.values_list('tipo_agenda', flat=True).first()
    esteira = tipo == TipoAgenda.KANBAN
    if request is not None:
        request._eh_esteira = esteira
    return esteira


def colaborador_aplicado(request, pedido: int | None) -> int | None:
    """O colaborador a aplicar num filtro de números (painel, caixa).

    Na esteira não há recorte por pessoa: a operação é do negócio inteiro, e o
    parâmetro é ignorado para todos (o colaborador comum nem chega aqui: é 403
    antes). No modo horário, o proprietário vê o que pediu (ou todos), e quem
    não é vê só os próprios números, seja o que for que veio na query: a trava
    fica aqui, não na tela, senão bastaria trocar o parâmetro. Sem perfil de
    colaborador, 404.
    """
    if eh_esteira(request):
        return None
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


def eh_parceiro(request) -> bool:
    return vinculo_do_usuario(request) == 'parceiro'


def eh_colaborador_comum(request) -> bool:
    return vinculo_do_usuario(request) == 'colaborador'


def ve_valores(request) -> bool:
    """Dono e parceiro veem dinheiro; o colaborador comum não."""
    return not eh_colaborador_comum(request)


def exigir_ver_valores(request) -> None:
    if not ve_valores(request):
        raise ErroDeNegocio('Você não tem acesso aos valores.', 'sem_acesso_a_valores', 403)


def exigir_poder_cobrar(request) -> None:
    """Dono e parceiro cobram sempre; o colaborador comum só com a flag ligada.

    É a regra da agenda. Na esteira a flag não pesa: o colaborador comum não
    cobra (as ações do quadro passam por `IsProprietarioOuParceiro`).
    """
    if eh_proprietario(request):
        return
    colaborador = colaborador_do(request)
    if colaborador is None:
        raise ErroDeNegocio('Usuário sem perfil de colaborador.', 'sem_colaborador', 404)
    if not colaborador.eh_parceiro and not colaborador.pode_cobrar:
        raise ErroDeNegocio('Você não pode registrar cobranças.', 'sem_permissao_cobrar', 403)


def exigir_poder_bloquear(request, colaborador_id: int) -> None:
    """Criar ou excluir bloqueio na agenda de `colaborador_id`. O dono mexe na
    agenda de todos; o parceiro, só na própria; o colaborador comum, em nenhuma
    (a agenda dele é decidida pelo dono)."""
    if eh_proprietario(request):
        return
    colaborador = colaborador_do(request)
    if colaborador is None or not colaborador.eh_parceiro:
        raise ErroDeNegocio('Você não pode bloquear a agenda.', 'sem_permissao_bloquear', 403)
    if colaborador.pk != colaborador_id:
        raise ErroDeNegocio('Você só pode bloquear a sua própria agenda.', 'sem_permissao_bloquear', 403)


def eh_proprietario_ou_parceiro_da_esteira(request) -> bool:
    """O dono sempre; na esteira também o parceiro, que toca o negócio com ele:
    serviços, modelos de contrato, caixa inteiro, capacidade do dia e fechar
    horário. A estrutura (equipe, assinatura, horários, dados do negócio,
    nichos e etapas) continua só do dono (`IsProprietario`)."""
    return eh_proprietario(request) or (eh_esteira(request) and eh_parceiro(request))


def eh_colaborador_da_esteira(request) -> bool:
    """O colaborador comum (vínculo `colaborador`) de um negócio de esteira: vê
    o quadro, move os cards e ajusta o tempo. O resto é 403."""
    return eh_esteira(request) and eh_colaborador_comum(request)


def exigir_nao_ser_colaborador_da_esteira(request) -> None:
    if eh_colaborador_da_esteira(request):
        raise ErroDeNegocio('Você não tem acesso a esta parte do app.', 'sem_permissao', 403)


class IsProprietario(BasePermission):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return eh_proprietario(request)


class IsProprietarioOuParceiro(BasePermission):
    """Dono ou parceiro, em qualquer modo: o que o colaborador comum não faz.
    É a trava das ações do quadro (receber, remarcar, falta, excluir, cobrar,
    ajustar o dia): a esteira é o próprio modo, então o vínculo basta."""

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return eh_proprietario(request) or eh_parceiro(request)


class IsProprietarioOuParceiroDaEsteira(BasePermission):
    """`eh_proprietario_ou_parceiro_da_esteira`, para o que os dois modos
    compartilham: escrita em serviços e modelos de contrato."""

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return eh_proprietario_ou_parceiro_da_esteira(request)


class SoOProprietarioNaEsteira(BasePermission):
    """Na esteira, só o dono; no modo horário, qualquer um autenticado. É a
    leitura da equipe e dos convites: na agenda a equipe se vê, na esteira a
    tela nem existe para quem não é dono. A regra fica na classe (e não no
    `get_permissions`) porque o gerador do OpenAPI chama `get_permissions`
    sem banco."""

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return eh_proprietario(request) or not eh_esteira(request)


class NaoEhColaboradorDaEsteira(BasePermission):
    """Barra o colaborador comum da esteira (403 `sem_permissao`): clientes,
    veículos e pets, serviços e contratos não são do quadro."""

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return not eh_colaborador_da_esteira(request)
