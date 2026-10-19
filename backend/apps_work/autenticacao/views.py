from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from core.sessao import entregar_refresh, refresh_da_requisicao
from tenants.models import UserTenant
from .models import CodigoRecuperacao, LastActivity
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

        try:
            user = User.objects.get(username=email)
        except User.DoesNotExist:
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
        email = request.data.get('email', '').strip().lower()
        codigo = request.data.get('codigo', '').strip()

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'detail': 'Código inválido.'}, status=status.HTTP_400_BAD_REQUEST)

        registro = CodigoRecuperacao.objects.filter(
            user=user, codigo=codigo, usado=False
        ).first()

        if not registro or registro.expirado:
            return Response({'detail': 'Código inválido ou expirado.'}, status=status.HTTP_400_BAD_REQUEST)

        return Response({'detail': 'Código válido.'})


class NovaSenhaView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth_verify'

    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        codigo = request.data.get('codigo', '').strip()
        nova_senha = request.data.get('nova_senha', '')

        try:
            validate_password(nova_senha)
        except DjangoValidationError as e:
            return Response({'detail': ' '.join(e.messages)}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'detail': 'Código inválido.'}, status=status.HTTP_400_BAD_REQUEST)

        registro = CodigoRecuperacao.objects.filter(
            user=user, codigo=codigo, usado=False
        ).first()

        if not registro or registro.expirado:
            return Response({'detail': 'Código inválido ou expirado.'}, status=status.HTTP_400_BAD_REQUEST)

        user.set_password(nova_senha)
        user.save()

        # Quem pediu a recuperação pode estar tirando um invasor da conta.
        from .services import SessaoService
        SessaoService().encerrar_todas(user)

        registro.usado = True
        registro.save()

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
