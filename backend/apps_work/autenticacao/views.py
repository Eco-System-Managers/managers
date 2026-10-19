from django.conf import settings
from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from core.sessao import entregar_refresh, refresh_da_requisicao
from tenants.models import UserTenant
from .models import LastActivity
from .serializers import CadastroSerializer

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
        path='/auth/',
    )


def delete_refresh_cookie(response: Response) -> None:
    response.delete_cookie(key=REFRESH_COOKIE, path='/auth/')


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

    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        senha = request.data.get('senha', '')

        user = User.objects.filter(username=email).first()
        if user is None:
            # Calcula um hash mesmo assim: sem isso, e-mail inexistente responde
            # mais rápido e o tempo de resposta revela quem tem conta.
            User().set_password(senha)
            return Response(
                {'detail': 'E-mail ou senha inválidos.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        if not user.check_password(senha):
            return Response(
                {'detail': 'E-mail ou senha inválidos.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        if not user.is_active:
            return Response(
                {
                    'detail': 'Você está inativo. Entre em contato com o proprietário do sistema.',
                    'code': 'user_inactive',
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        user_tenant = UserTenant.objects.filter(user=user).select_related('tenant').first()
        if not user_tenant:
            return Response(
                {'detail': 'Usuário não vinculado a nenhuma empresa.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        tenant = user_tenant.tenant

        from django.utils import timezone
        LastActivity.objects.update_or_create(user=user, defaults={'ultimo_acesso': timezone.now()})

        from .services import SessaoService
        refresh = SessaoService().emitir(user, tenant)
        return responder_sessao(request, refresh)


class RecuperarSenhaView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth_recovery'

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

    def post(self, request):
        from .services import RecuperacaoSenhaService
        email = request.data.get('email', '')
        codigo = request.data.get('codigo', '').strip()

        if not RecuperacaoSenhaService().verificar_codigo(email, codigo):
            return Response({'detail': 'Código inválido ou expirado.'}, status=status.HTTP_400_BAD_REQUEST)

        return Response({'detail': 'Código válido.'})


class NovaSenhaView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth_verify'

    def post(self, request):
        from .services import RecuperacaoSenhaService
        email = request.data.get('email', '')
        codigo = request.data.get('codigo', '').strip()
        nova_senha = request.data.get('nova_senha', '')

        try:
            RecuperacaoSenhaService().redefinir_senha(email, codigo, nova_senha)
        except ValueError as e:
            return Response({'detail': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response({'detail': 'Senha redefinida com sucesso.'})


class CookieTokenRefreshView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        from .services import SessaoInvalida, SessaoService

        token_str = refresh_da_requisicao(request, REFRESH_COOKIE)
        try:
            if not token_str:
                raise SessaoInvalida()
            refresh = SessaoService().renovar(token_str)
        except SessaoInvalida:
            response = Response(
                {'detail': 'Sessão expirada. Faça login novamente.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )
            delete_refresh_cookie(response)
            return response
        return responder_sessao(request, refresh)


class LogoutView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        from .services import SessaoService

        token_str = refresh_da_requisicao(request, REFRESH_COOKIE)
        if token_str:
            SessaoService().encerrar(token_str)
        response = Response({'detail': 'Logout realizado com sucesso.'})
        delete_refresh_cookie(response)
        return response
