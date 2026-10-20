from django.conf import settings
from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from drf_spectacular.utils import extend_schema

from core import rotas
from core.openapi import PLATAFORMA, MensagemSerializer
from core.limites import MuitasTentativas, login_work
from core.sessao import entregar_refresh, refresh_da_requisicao
from core.throttling import RecuperacaoPorEmailThrottle
from tenants.models import UserTenant
from .models import LastActivity
from .serializers import (
    CadastroSerializer, EmailSerializer, LoginSerializer, NovaSenhaSerializer, RefreshSerializer,
    SessaoSerializer, VerificarCodigoSerializer,
)
from core.excecoes import erro

REFRESH_COOKIE = 'refresh_token'
REFRESH_COOKIE_MAX_AGE = 7 * 24 * 3600  # 7 dias


def set_refresh_cookie(response: Response, token_str: str) -> None:
    response.set_cookie(
        key=REFRESH_COOKIE,
        value=token_str,
        httponly=True,
        secure=not settings.DEBUG,
        samesite='Lax',
        max_age=REFRESH_COOKIE_MAX_AGE,
        path=rotas.WORK_AUTH,
    )


def delete_refresh_cookie(response: Response) -> None:
    response.delete_cookie(key=REFRESH_COOKIE, path=rotas.WORK_AUTH)


def responder_sessao(request, refresh, status_code=status.HTTP_200_OK) -> Response:
    """Resposta de login, cadastro, renovação e aceite de convite."""
    response = Response({
        'access': str(refresh.access_token),
        'schema_name': refresh['schema_name'],
        'empresa': refresh['empresa'],
    }, status=status_code)
    entregar_refresh(request, response, str(refresh), set_refresh_cookie)
    return response


class CadastroView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth_cadastro'

    @extend_schema(
        request=CadastroSerializer, responses={201: SessaoSerializer}, parameters=[PLATAFORMA],
        summary='Cadastrar empresa e dono',
    )
    def post(self, request):
        serializer = CadastroSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user, tenant = serializer.save()

        from django.utils import timezone
        LastActivity.objects.create(user=user, ultimo_acesso=timezone.now())

        from .services import SessaoService
        refresh = SessaoService().emitir(user, tenant)
        return responder_sessao(request, refresh, status.HTTP_201_CREATED)


class LoginView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth_login'

    @extend_schema(
        request=LoginSerializer, responses=SessaoSerializer, parameters=[PLATAFORMA],
        summary='Entrar com e-mail e senha',
    )
    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        senha = request.data.get('senha', '')

        try:
            login_work.verificar(email)
        except MuitasTentativas as e:
            return erro(str(e), 'muitas_tentativas', status.HTTP_429_TOO_MANY_REQUESTS)

        user = User.objects.filter(username=email).first()
        if user is None:
            # Calcula um hash mesmo assim: sem isso, e-mail inexistente responde
            # mais rápido e o tempo de resposta revela quem tem conta.
            User().set_password(senha)
        if user is None or not user.check_password(senha):
            login_work.registrar_falha(email)
            return erro('E-mail ou senha inválidos.', status_code=status.HTTP_401_UNAUTHORIZED)
        login_work.limpar(email)

        if not user.is_active:
            return erro('Você está inativo. Entre em contato com o proprietário do sistema.', 'user_inactive', status.HTTP_403_FORBIDDEN)

        user_tenant = UserTenant.objects.filter(user=user).select_related('tenant').first()
        if not user_tenant:
            return erro('Usuário não vinculado a nenhuma empresa.', status_code=status.HTTP_400_BAD_REQUEST)

        tenant = user_tenant.tenant

        from django.utils import timezone
        LastActivity.objects.update_or_create(user=user, defaults={'ultimo_acesso': timezone.now()})

        from .services import SessaoService
        refresh = SessaoService().emitir(user, tenant)
        return responder_sessao(request, refresh)


class RecuperarSenhaView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle, RecuperacaoPorEmailThrottle]
    throttle_scope = 'auth_recovery'

    @extend_schema(
        request=EmailSerializer, responses=MensagemSerializer,
        summary='Pedir código de recuperação de senha',
        description='Responde sempre a mesma mensagem, exista ou não a conta.',
    )
    def post(self, request):
        from .services import RecuperacaoSenhaService
        email = request.data.get('email', '').strip()
        msg = RecuperacaoSenhaService().recuperar(email)
        return Response({'detail': msg})


class VerificarCodigoView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth_verify'

    @extend_schema(
        request=VerificarCodigoSerializer, responses=MensagemSerializer,
        summary='Conferir código de recuperação',
    )
    def post(self, request):
        from .services import RecuperacaoSenhaService
        email = request.data.get('email', '')
        codigo = request.data.get('codigo', '').strip()

        if not RecuperacaoSenhaService().verificar_codigo(email, codigo):
            return erro('Código inválido ou expirado.', status_code=status.HTTP_400_BAD_REQUEST)

        return Response({'detail': 'Código válido.'})


class NovaSenhaView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth_verify'

    @extend_schema(
        request=NovaSenhaSerializer, responses=MensagemSerializer,
        summary='Redefinir senha com o código',
    )
    def post(self, request):
        from .services import RecuperacaoSenhaService
        email = request.data.get('email', '')
        codigo = request.data.get('codigo', '').strip()
        nova_senha = request.data.get('nova_senha', '')

        try:
            RecuperacaoSenhaService().redefinir_senha(email, codigo, nova_senha)
        except ValueError as e:
            return erro(str(e), getattr(e, 'code', None), status.HTTP_400_BAD_REQUEST)

        return Response({'detail': 'Senha redefinida com sucesso.'})


class CookieTokenRefreshView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    @extend_schema(
        request=RefreshSerializer, responses=SessaoSerializer, parameters=[PLATAFORMA],
        summary='Renovar a sessão',
        description='Cada refresh vale uma vez: a resposta traz um novo (cookie no web, corpo no mobile).',
    )
    def post(self, request):
        from .services import SessaoInvalida, SessaoService

        token_str = refresh_da_requisicao(request, REFRESH_COOKIE)
        try:
            if not token_str:
                raise SessaoInvalida()
            refresh = SessaoService().renovar(token_str)
        except SessaoInvalida:
            response = erro('Sessão expirada. Faça login novamente.', status_code=status.HTTP_401_UNAUTHORIZED)
            delete_refresh_cookie(response)
            return response
        return responder_sessao(request, refresh)


class LogoutView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    @extend_schema(
        request=RefreshSerializer, responses=MensagemSerializer, parameters=[PLATAFORMA],
        summary='Sair (revoga o refresh)',
    )
    def post(self, request):
        from .services import SessaoService

        token_str = refresh_da_requisicao(request, REFRESH_COOKIE)
        if token_str:
            SessaoService().encerrar(token_str)
        response = Response({'detail': 'Logout realizado com sucesso.'})
        delete_refresh_cookie(response)
        return response
