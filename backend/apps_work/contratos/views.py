from django.db import connection
from django_tenants.utils import schema_context
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Contrato, ModeloContrato
from .serializers import (
    AssinarContratoSerializer,
    ContratoPublicoSerializer,
    ContratoSerializer,
    GerarContratoSerializer,
    ModeloContratoSerializer,
)
from .services import ContratoService
from core.excecoes import erro
from core.schemas import schema_valido


class ModeloContratoViewSet(viewsets.ModelViewSet):
    serializer_class = ModeloContratoSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return ModeloContrato.objects.all()


class ContratoViewSet(viewsets.ModelViewSet):
    serializer_class = ContratoSerializer
    permission_classes = [IsAuthenticated]
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
        # schema_name vem da URL pública: sem checar, schema inexistente dava
        # 500 e o público era alcançável.
        from tenants.models import Tenant
        if not schema_valido(schema_name) or not Tenant.objects.filter(schema_name=schema_name).exists():
            return None
        try:
            with schema_context(schema_name):
                return Contrato.objects.select_related('cliente').get(token=token)
        except Contrato.DoesNotExist:
            return None

    def get(self, request, schema_name: str, token: str):
        contrato = self._get_contrato(schema_name, token)
        if not contrato:
            return erro('Contrato não encontrado.', status_code=status.HTTP_404_NOT_FOUND)
        with schema_context(schema_name):
            data = ContratoPublicoSerializer(contrato).data
        return Response(data)

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
                    ip = (
                        request.META.get('HTTP_X_FORWARDED_FOR', '').split(',')[0].strip()
                        or request.META.get('REMOTE_ADDR', '')
                    )
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
