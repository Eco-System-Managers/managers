from rest_framework import status
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from drf_spectacular.utils import extend_schema

from apps_serv.consumidores.serializers import CadastroConsumidorSerializer, ConsumidorSerializer
from apps_serv.consumidores.services import (
    LoginConsumidorService,
    RecuperacaoSenhaConsumidorService,
    RegistroConsumidorService,
)
from core import rotas
from core.limites import MuitasTentativas
from core.openapi import PLATAFORMA, MensagemSerializer
from core.sessao import entregar_refresh, refresh_da_requisicao
from core.throttling import RecuperacaoConsumidorPorEmailThrottle

from .authentication import gerar_tokens, renovar_tokens, revogar_refresh
from .serializers import (
    LoginConsumidorSerializer,
    NovaSenhaConsumidorSerializer,
    RecuperarSenhaConsumidorSerializer,
    RefreshConsumidorSerializer,
    RenovacaoConsumidorSerializer,
    SessaoConsumidorSerializer,
    VerificarCodigoConsumidorSerializer,
)
from core.excecoes import erro

REFRESH_COOKIE = 'sm_refresh_token'
REFRESH_COOKIE_MAX_AGE = 7 * 24 * 3600


def _set_refresh_cookie(response: Response, token_str: str) -> None:
    from django.conf import settings
    response.set_cookie(
        key=REFRESH_COOKIE,
        value=token_str,
        httponly=True,
        secure=not settings.DEBUG,
        samesite='Lax',
        max_age=REFRESH_COOKIE_MAX_AGE,
        path=rotas.SERVICEMANAGE_AUTH,
    )


def _delete_refresh_cookie(response: Response) -> None:
    response.delete_cookie(key=REFRESH_COOKIE, path=rotas.SERVICEMANAGE_AUTH)


class CadastroConsumidorView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'sm_auth_cadastro'

    @extend_schema(
        request=CadastroConsumidorSerializer,
        responses={201: SessaoConsumidorSerializer},
        parameters=[PLATAFORMA],
        summary='Criar conta de cliente',
    )
    def post(self, request):
        serializer = CadastroConsumidorSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            consumidor = RegistroConsumidorService().registrar(
                nome=serializer.validated_data['nome'],
                email=serializer.validated_data['email'],
                senha=serializer.validated_data['senha'],
                telefone=serializer.validated_data.get('telefone', ''),
            )
        except ValueError as e:
            return erro(str(e), getattr(e, 'code', None), status.HTTP_400_BAD_REQUEST)

        access, refresh = gerar_tokens(consumidor)
        response = Response(
            {'access': access, 'consumidor': ConsumidorSerializer(consumidor).data},
            status=status.HTTP_201_CREATED,
        )
        entregar_refresh(request, response, refresh, _set_refresh_cookie)
        return response


class LoginConsumidorView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'sm_auth_login'

    @extend_schema(
        request=LoginConsumidorSerializer, responses=SessaoConsumidorSerializer, parameters=[PLATAFORMA],
        summary='Entrar com e-mail e senha',
    )
    def post(self, request):
        email = request.data.get('email', '')
        senha = request.data.get('senha', '')

        try:
            consumidor = LoginConsumidorService().autenticar(email=email, senha=senha)
        except MuitasTentativas as e:
            return erro(str(e), 'muitas_tentativas', status.HTTP_429_TOO_MANY_REQUESTS)
        except ValueError as e:
            return erro(str(e), getattr(e, 'code', None), status.HTTP_401_UNAUTHORIZED)

        access, refresh = gerar_tokens(consumidor)
        response = Response({
            'access': access,
            'consumidor': ConsumidorSerializer(consumidor).data,
        })
        entregar_refresh(request, response, refresh, _set_refresh_cookie)
        return response


class RefreshConsumidorView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    @extend_schema(
        request=RefreshConsumidorSerializer, responses=RenovacaoConsumidorSerializer, parameters=[PLATAFORMA],
        summary='Renovar a sessão (o refresh usado deixa de valer)',
    )
    def post(self, request):
        token_str = refresh_da_requisicao(request, REFRESH_COOKIE)
        if not token_str:
            return erro('Sessão expirada. Faça login novamente.', status_code=status.HTTP_401_UNAUTHORIZED)

        try:
            access, refresh, _ = renovar_tokens(token_str)
        except AuthenticationFailed as e:
            response = erro(str(e.detail), status_code=status.HTTP_401_UNAUTHORIZED)
            _delete_refresh_cookie(response)
            return response

        response = Response({'access': access})
        entregar_refresh(request, response, refresh, _set_refresh_cookie)
        return response


class LogoutConsumidorView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    @extend_schema(
        request=RefreshConsumidorSerializer, responses=MensagemSerializer, parameters=[PLATAFORMA],
        summary='Sair (revoga o refresh)',
    )
    def post(self, request):
        token_str = refresh_da_requisicao(request, REFRESH_COOKIE)
        if token_str:
            revogar_refresh(token_str)
        response = Response({'detail': 'Logout realizado com sucesso.'})
        _delete_refresh_cookie(response)
        return response


class RecuperarSenhaConsumidorView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle, RecuperacaoConsumidorPorEmailThrottle]
    throttle_scope = 'sm_auth_recovery'

    @extend_schema(
        request=RecuperarSenhaConsumidorSerializer, responses=MensagemSerializer,
        summary='Pedir código de recuperação de senha',
        description='Responde a mesma mensagem exista ou não a conta.',
    )
    def post(self, request):
        email = request.data.get('email', '').strip()
        msg = RecuperacaoSenhaConsumidorService().solicitar(email)
        return Response({'detail': msg})


class VerificarCodigoConsumidorView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'sm_auth_verify'

    @extend_schema(
        request=VerificarCodigoConsumidorSerializer, responses=MensagemSerializer,
        summary='Conferir o código de recuperação',
    )
    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        codigo = request.data.get('codigo', '').strip()

        if not RecuperacaoSenhaConsumidorService().verificar_codigo(email, codigo):
            return erro('Código inválido ou expirado.', status_code=status.HTTP_400_BAD_REQUEST)

        return Response({'detail': 'Código válido.'})


class NovaSenhaConsumidorView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'sm_auth_verify'

    @extend_schema(
        request=NovaSenhaConsumidorSerializer, responses=MensagemSerializer,
        summary='Definir nova senha com o código (derruba as sessões abertas)',
    )
    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        codigo = request.data.get('codigo', '').strip()
        nova_senha = request.data.get('nova_senha', '')

        try:
            RecuperacaoSenhaConsumidorService().redefinir_senha(email, codigo, nova_senha)
        except ValueError as e:
            return erro(str(e), getattr(e, 'code', None), status.HTTP_400_BAD_REQUEST)

        return Response({'detail': 'Senha redefinida com sucesso.'})
