from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from drf_spectacular.utils import extend_schema

from core.openapi import PLATAFORMA, MensagemSerializer
from core.sessao import COOKIE_WORK
from core.throttling import CadastroPorEmailThrottle, RecuperacaoPorEmailThrottle
from .serializers import (
    CadastroSerializer, ConfirmarCadastroSerializer, EmailSerializer, LoginSerializer, NovaSenhaSerializer, RefreshSerializer,
    SessaoSerializer, VerificarCodigoSerializer,
)
from core.excecoes import erro

def responder_sessao(request, refresh, status_code=status.HTTP_200_OK) -> Response:
    """Resposta de login, cadastro, renovação e aceite de convite."""
    response = Response({
        'access': str(refresh.access_token),
        'schema_name': refresh['schema_name'],
        'empresa': refresh['empresa'],
    }, status=status_code)
    COOKIE_WORK.entregar(request, response, str(refresh))
    return response


class CadastroView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth_cadastro'

    @extend_schema(
        request=CadastroSerializer, responses={201: SessaoSerializer}, parameters=[PLATAFORMA],
        summary='Cadastrar empresa e dono (sem confirmar o e-mail)',
        description=(
            'Cria a empresa na hora, sem confirmar que o e-mail é de quem se cadastra. '
            'Fica enquanto os apps migram para o cadastro com confirmação '
            '(`/auth/cadastro/solicitar/` e `/auth/cadastro/confirmar/`), e depois sai.'
        ),
        deprecated=True,
    )
    def post(self, request):
        serializer = CadastroSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user, tenant = serializer.save()

        from .services import SessaoService
        refresh = SessaoService().emitir(user, tenant)
        return responder_sessao(request, refresh, status.HTTP_201_CREATED)


class CadastroSolicitarView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle, CadastroPorEmailThrottle]
    throttle_scope = 'auth_cadastro'

    @extend_schema(
        request=CadastroSerializer, responses={202: MensagemSerializer},
        summary='Cadastrar empresa e dono: envia o código de confirmação',
        description=(
            'Valida os dados e envia um código para o e-mail. A empresa ainda não existe: '
            'ela é criada em `/auth/cadastro/confirmar/`. Pedir de novo com o mesmo e-mail '
            'substitui os dados e invalida o código anterior.'
        ),
    )
    def post(self, request):
        from .services import ConfirmacaoCadastroService
        serializer = CadastroSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        ConfirmacaoCadastroService().solicitar(**serializer.validated_data)
        return Response({'detail': ConfirmacaoCadastroService.MENSAGEM}, status=status.HTTP_202_ACCEPTED)


class CadastroConfirmarView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth_verify'

    @extend_schema(
        request=ConfirmarCadastroSerializer, responses={201: SessaoSerializer}, parameters=[PLATAFORMA],
        summary='Confirmar o cadastro com o código (cria a empresa e devolve a sessão)',
    )
    def post(self, request):
        from .services import ConfirmacaoCadastroService, SessaoService
        serializer = ConfirmarCadastroSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user, tenant = ConfirmacaoCadastroService().confirmar(
            serializer.validated_data['email'], serializer.validated_data['codigo'].strip(),
        )
        refresh = SessaoService().emitir(user, tenant)
        return responder_sessao(request, refresh, status.HTTP_201_CREATED)


class CadastroReenviarView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle, CadastroPorEmailThrottle]
    throttle_scope = 'auth_recovery'

    @extend_schema(
        request=EmailSerializer, responses={202: MensagemSerializer},
        summary='Reenviar o código de confirmação do cadastro',
        description='Responde sempre a mesma mensagem, exista ou não um cadastro pendente.',
    )
    def post(self, request):
        from .services import ConfirmacaoCadastroService
        serializer = EmailSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        ConfirmacaoCadastroService().reenviar(serializer.validated_data['email'])
        return Response({'detail': ConfirmacaoCadastroService.MENSAGEM}, status=status.HTTP_202_ACCEPTED)


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
        from .services import LoginService, SessaoService
        # Credencial errada, usuário inativo, sem empresa e limite de falhas
        # levantam ErroDeNegocio com o status certo; o handler monta a resposta.
        user, tenant = LoginService().autenticar(
            request.data.get('email', ''), request.data.get('senha', ''),
        )
        return responder_sessao(request, SessaoService().emitir(user, tenant))


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
        msg = RecuperacaoSenhaService().solicitar(email)
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

        token_str = COOKIE_WORK.refresh_da_requisicao(request)
        try:
            if not token_str:
                raise SessaoInvalida()
            refresh = SessaoService().renovar(token_str)
        except SessaoInvalida:
            response = erro('Sessão expirada. Faça login novamente.', status_code=status.HTTP_401_UNAUTHORIZED)
            COOKIE_WORK.apagar(response)
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

        token_str = COOKIE_WORK.refresh_da_requisicao(request)
        if token_str:
            SessaoService().encerrar(token_str)
        response = Response({'detail': 'Logout realizado com sucesso.'})
        COOKIE_WORK.apagar(response)
        return response
