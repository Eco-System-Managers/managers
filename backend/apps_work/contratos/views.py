from django.db import connection
from django_tenants.utils import schema_context
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import BaseThrottle
from rest_framework.views import APIView
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view

from .models import Contrato, ModeloContrato, StatusContrato
from .serializers import (
    AcaoContratoPublicoSerializer,
    AssinarContratoSerializer,
    ContratoPublicoSerializer,
    ContratoSerializer,
    GerarContratoSerializer,
    MarcarContratoSerializer,
    ModeloContratoSerializer,
)
from .services import ContratoService, contrato_publico
from core.excecoes import erro
from core.permissions import IsProprietario


@extend_schema_view(
    list=extend_schema(
        parameters=[OpenApiParameter('ativo', OpenApiTypes.BOOL, description='Só os ativos (true) ou só os inativos (false).')],
    ),
)
class ModeloContratoViewSet(viewsets.ModelViewSet):
    serializer_class = ModeloContratoSerializer
    permission_classes = [IsAuthenticated]

    # o modelo é texto do negócio: qualquer um da equipe gera contrato com
    # ele, mas só o proprietário escreve
    _ACOES_DO_PROPRIETARIO = ('create', 'update', 'partial_update', 'destroy')

    def get_permissions(self):
        if self.action in self._ACOES_DO_PROPRIETARIO:
            return [IsAuthenticated(), IsProprietario()]
        return super().get_permissions()

    def get_queryset(self):
        qs = ModeloContrato.objects.all()
        ativo = self.request.query_params.get('ativo')
        if ativo in ('true', 'false'):
            qs = qs.filter(ativo=ativo == 'true')
        return qs


@extend_schema_view(
    list=extend_schema(
        parameters=[
            OpenApiParameter('cliente', OpenApiTypes.INT, description='Só os contratos deste cliente.'),
            OpenApiParameter('status', OpenApiTypes.STR, enum=[c.value for c in StatusContrato]),
        ],
    ),
)
class ContratoViewSet(viewsets.ModelViewSet):
    serializer_class = ContratoSerializer
    permission_classes = [IsAuthenticated]

    def perform_destroy(self, instance):
        ContratoService().remover(instance)

    def get_queryset(self):
        qs = Contrato.objects.select_related('cliente', 'modelo')
        cliente_id = self.request.query_params.get('cliente')
        status_filtro = self.request.query_params.get('status')
        if cliente_id:
            qs = qs.filter(cliente_id=cliente_id)
        if status_filtro:
            qs = qs.filter(status=status_filtro)
        # Ordem estavel: sem ela o Postgres pode devolver o mesmo contrato em
        # duas paginas e omitir outro.
        return qs.order_by('-criado_em', '-id')

    @extend_schema(request=GerarContratoSerializer, responses={201: ContratoSerializer}, summary='Gerar contrato a partir de um modelo')
    @action(detail=False, methods=['post'])
    def gerar(self, request):
        serializer = GerarContratoSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            modelo = ModeloContrato.objects.get(pk=serializer.validated_data['modelo_id'])
        except ModeloContrato.DoesNotExist:
            return erro('Modelo não encontrado.', 'modelo_nao_encontrado', status.HTTP_404_NOT_FOUND)

        from apps_work.clientes.models import Cliente
        try:
            cliente = Cliente.objects.get(pk=serializer.validated_data['cliente_id'])
        except Cliente.DoesNotExist:
            return erro('Cliente não encontrado.', 'cliente_nao_encontrado', status.HTTP_404_NOT_FOUND)

        contrato = ContratoService().gerar(modelo, cliente)
        return Response(ContratoSerializer(contrato).data, status=status.HTTP_201_CREATED)

    @extend_schema(
        request=MarcarContratoSerializer, responses={200: ContratoSerializer},
        summary='Marcar o contrato como enviado, assinado ou recusado',
        description='Para o que acontece fora do sistema: o PDF compartilhado pelo app, a assinatura no papel.',
    )
    @action(detail=True, methods=['post'])
    def marcar(self, request, pk=None):
        serializer = MarcarContratoSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        contrato = ContratoService().marcar(
            self.get_object(),
            serializer.validated_data['status'],
            serializer.validated_data.get('nome_assinante', ''),
        )
        return Response(ContratoSerializer(contrato).data)

    @extend_schema(request=None, responses={200: ContratoSerializer}, summary='Enviar contrato por e-mail ao cliente')
    @action(detail=True, methods=['post'])
    def enviar(self, request, pk=None):
        contrato = self.get_object()
        schema_name = connection.schema_name
        try:
            ContratoService().enviar(contrato, schema_name)
        except ValueError as e:
            return erro(str(e), getattr(e, 'code', 'envio_invalido'), status.HTTP_400_BAD_REQUEST)
        return Response(ContratoSerializer(contrato).data)


# ---------------------------------------------------------------------------
# Endpoint público — acessado pelo cliente via link do email (sem autenticação)
# ---------------------------------------------------------------------------

class ContratoPublicoView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def _get_contrato(self, schema_name: str, token: str):
        return contrato_publico(schema_name, token)

    @extend_schema(responses=ContratoPublicoSerializer, summary='Contrato aberto pelo link do e-mail')
    def get(self, request, schema_name: str, token: str):
        contrato = self._get_contrato(schema_name, token)
        if not contrato:
            return erro('Contrato não encontrado.', status_code=status.HTTP_404_NOT_FOUND)
        with schema_context(schema_name):
            data = ContratoPublicoSerializer(contrato).data
        return Response(data)

    @extend_schema(
        request=AcaoContratoPublicoSerializer, responses=ContratoPublicoSerializer,
        summary='Assinar ou recusar o contrato',
    )
    def post(self, request, schema_name: str, token: str):
        acao = request.data.get('acao')
        if acao not in ('assinar', 'recusar'):
            return erro('Ação inválida. Use "assinar" ou "recusar".', status_code=status.HTTP_400_BAD_REQUEST)

        contrato = self._get_contrato(schema_name, token)
        if not contrato:
            return erro('Contrato não encontrado.', status_code=status.HTTP_404_NOT_FOUND)

        service = ContratoService()

        with schema_context(schema_name):
            try:
                if acao == 'assinar':
                    serializer = AssinarContratoSerializer(data=request.data)
                    serializer.is_valid(raise_exception=True)
                    # Mesma identificação do rate limiting (NUM_PROXIES): o
                    # X-Forwarded-For cru é escrito pelo cliente e forjaria o IP
                    # registrado na assinatura.
                    ip = BaseThrottle().get_ident(request)
                    contrato = service.assinar(
                        contrato,
                        nome_assinante=serializer.validated_data['nome_assinante'],
                        ip=ip,
                    )
                else:
                    contrato = service.recusar(contrato)
            except ValueError as e:
                return erro(str(e), getattr(e, 'code', 'acao_invalida'), status.HTTP_400_BAD_REQUEST)

        return Response(ContratoPublicoSerializer(contrato).data)
