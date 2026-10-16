from datetime import timedelta

from django.conf import settings
from django.core.cache import cache
from django.db import connection
from django.http import JsonResponse
from django.utils import timezone
from rest_framework_simplejwt.tokens import AccessToken

from core.cache import TTL_ASSINATURA_SEGUNDOS, chave_assinatura_bloqueada

_INACTIVITY_SKIP = {
    '/auth/login/',
    '/auth/cadastro/',
    '/auth/recuperar-senha/',
    '/auth/verificar-codigo/',
    '/auth/nova-senha/',
    '/api/token/refresh/',
    '/admin/',
    # Service Manage (B2C)
    '/api/sm/auth/cadastro/',
    '/api/sm/auth/login/',
    '/api/sm/auth/refresh/',
    '/api/sm/auth/logout/',
}


_TOKEN_NO_REQUEST = '_access_token_decodificado'


def _token_do_request(request):
    """Decodifica o Bearer uma unica vez por requisicao.

    Dois middlewares precisam do mesmo token — um para descobrir o schema do
    tenant, outro para o user_id. Cada um decodificava por conta propria, o que
    significa validar a assinatura HMAC duas vezes na mesma requisicao.

    Devolve None quando nao ha Bearer ou quando o token nao e valido; quem
    chama decide o que fazer. O resultado fica guardado no proprio request,
    inclusive quando e None, para a segunda chamada nao repetir o trabalho.
    """
    if hasattr(request, _TOKEN_NO_REQUEST):
        return getattr(request, _TOKEN_NO_REQUEST)

    token = None
    cabecalho = request.headers.get('Authorization', '')
    if cabecalho.startswith('Bearer '):
        try:
            token = AccessToken(cabecalho.split(' ', 1)[1])
        except Exception:
            token = None

    setattr(request, _TOKEN_NO_REQUEST, token)
    return token


class InactivityMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if not any(request.path.startswith(p) for p in _INACTIVITY_SKIP):
            token = _token_do_request(request)
            if token is not None:
                expirou = self._registrar_atividade(token)
                if expirou is not None:
                    return expirou

        return self.get_response(request)

    def _registrar_atividade(self, token):
        """Move o relogio de atividade do usuario.

        Devolve a resposta de sessao expirada quando o tempo ocioso passou do
        limite, e None caso contrario. Falha aqui nunca derruba a requisicao:
        controle de inatividade e conveniencia, nao autenticacao.
        """
        try:
            from apps_work.autenticacao.models import LastActivity

            agora = timezone.now()
            timeout = timedelta(minutes=getattr(settings, 'INACTIVITY_TIMEOUT_MINUTES', 30))

            registro, criado = LastActivity.objects.get_or_create(
                user_id=token['user_id'],
                defaults={'ultimo_acesso': agora},
            )
            if criado:
                return None

            ocioso = agora - registro.ultimo_acesso
            if ocioso > timeout:
                return JsonResponse(
                    {
                        'detail': 'Sessão expirada por inatividade. Faça login novamente.',
                        'code': 'inactivity_timeout',
                    },
                    status=401,
                )

            # Escrita amortizada. Antes era um UPDATE por requisicao, so para
            # adiantar o relogio alguns milissegundos — o custo mais alto do
            # middleware, e o unico que escreve. Com a janela, o valor guardado
            # fica no maximo `janela` atrasado; como a janela e ordens de
            # grandeza menor que o timeout, o momento do logout nao muda de
            # forma perceptivel.
            janela = timedelta(seconds=getattr(settings, 'INACTIVITY_WRITE_WINDOW_SECONDS', 60))
            if ocioso >= janela:
                registro.ultimo_acesso = agora
                registro.save(update_fields=['ultimo_acesso'])

            return None
        except Exception:
            return None


class JWTTenantMiddleware:
    """
    Em desenvolvimento (localhost), o TenantMainMiddleware não encontra um tenant
    pelo domínio e permanece no schema public. Este middleware lê o schema_name
    do JWT e troca para o schema correto do tenant.

    Em produção, o TenantMainMiddleware já setou o schema correto via subdomínio,
    então connection.schema_name != 'public' e este middleware não age.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if connection.schema_name == 'public':
            token = _token_do_request(request)
            if token is not None:
                schema_name = token.get('schema_name')
                if schema_name and schema_name != 'public':
                    connection.set_schema(schema_name)

        return self.get_response(request)


_BLOQUEIO_ISENTOS = (
    '/api/billing/',
    # /me/ identifica o usuário logado e decide se ele pode ver o botão de
    # assinar (só o proprietário pode) — precisa funcionar mesmo bloqueado,
    # senão ninguém consegue sair do estado bloqueado.
    '/api/colaboradores/me/',
    # PrivateRoute (frontend) consulta isso pra saber se o onboarding foi
    # concluído antes mesmo de decidir pra onde navegar — sem essa isenção,
    # todo tenant bloqueado é jogado de volta pro login em vez de continuar
    # logado e cair na tela de Pagamentos.
    '/api/empresa/config/',
)


class AssinaturaBloqueadaMiddleware:
    """
    Bloqueia requisições à API de um tenant sem assinatura válida (trial vencido,
    inadimplente, cancelada ou sem nenhuma Assinatura cadastrada). Os endpoints em
    _BLOQUEIO_ISENTOS ficam de fora pra não travar a própria tela que resolve a
    pendência (billing) nem a checagem de identidade que decide quem pode agir nela.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if (
            connection.schema_name != 'public'
            and request.path.startswith('/api/')
            and not any(request.path.startswith(p) for p in _BLOQUEIO_ISENTOS)
        ):
            if self._bloqueada(connection.schema_name):
                return JsonResponse(
                    {
                        'detail': 'Assinatura inativa. Assine o plano Pro para continuar.',
                        'code': 'assinatura_bloqueada',
                    },
                    status=402,
                )

        return self.get_response(request)

    def _bloqueada(self, schema_name: str) -> bool:
        """Estado de bloqueio do tenant, memorizado por um intervalo curto.

        Este middleware roda em toda requisicao de API, e a resposta muda no
        ritmo de eventos de cobranca — nao no de requisicoes. Consultar o banco
        toda vez era pagar duas consultas para obter um valor que passa horas
        sem mudar.
        """
        chave = chave_assinatura_bloqueada(schema_name)
        memorizado = cache.get(chave)
        if memorizado is not None:
            return memorizado

        from apps_work.billing.models import Assinatura

        # Uma consulta no lugar de duas: o Tenant era buscado apenas para servir
        # de filtro da Assinatura, e o join faz o mesmo de uma vez so.
        assinatura = Assinatura.objects.filter(tenant__schema_name=schema_name).first()
        bloqueada = assinatura is None or assinatura.bloqueada

        cache.set(chave, bloqueada, TTL_ASSINATURA_SEGUNDOS)
        return bloqueada
