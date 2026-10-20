from django.conf import settings
from django.db import connection
from django.http import HttpResponseRedirect
from rest_framework import status
from rest_framework.generics import ListAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.response import Response
from rest_framework.views import APIView

from core.permissions import IsProprietario
from .models import Assinatura, Pagamento, Plano
from .serializers import AssinaturaSerializer, PagamentoSerializer
from .services import (
    AssinaturaInvalidaError,
    MercadoPagoService,
    PreapprovalInvalidoError,
    WebhookInvalidoError,
)
from core.excecoes import erro


class MinhaAssinaturaView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from tenants.models import Tenant

        tenant = Tenant.objects.get(schema_name=connection.schema_name)
        try:
            assinatura = tenant.assinatura
        except Assinatura.DoesNotExist:
            return erro('Este negócio ainda não tem assinatura.', status_code=status.HTTP_404_NOT_FOUND)

        return Response(AssinaturaSerializer(assinatura).data)


class IniciarAssinaturaView(APIView):
    permission_classes = [IsAuthenticated, IsProprietario]

    def post(self, request):
        plano = Plano.objects.filter(nome='pro', ativo=True).first()
        if plano is None:
            return erro('Plano Pro não está configurado.', status_code=status.HTTP_400_BAD_REQUEST)

        try:
            init_point = MercadoPagoService().obter_link_assinatura(plano)
        except AssinaturaInvalidaError as e:
            return erro(str(e), getattr(e, 'code', None), status.HTTP_400_BAD_REQUEST)

        return Response({'init_point': init_point})


class RetornoCheckoutView(APIView):
    """Recebe o redirect do Mercado Pago após o checkout (back_url) e repassa
    pro frontend com a mesma query string — não interpreta nada aqui, só
    resolve o back_url precisar ser um domínio público (https/ngrok em dev,
    o domínio real em produção), diferente do frontend, que pode estar em
    localhost em dev."""

    permission_classes = [AllowAny]

    def get(self, request):
        query = request.META.get('QUERY_STRING', '')
        destino = f'{settings.FRONTEND_URL}/app/pagamentos' + (f'?{query}' if query else '')
        return HttpResponseRedirect(destino)


class ConfirmarAssinaturaView(APIView):
    permission_classes = [IsAuthenticated, IsProprietario]

    def post(self, request):
        preapproval_id = request.data.get('preapproval_id')
        if not preapproval_id:
            return erro('preapproval_id é obrigatório.', status_code=status.HTTP_400_BAD_REQUEST)

        from tenants.models import Tenant

        tenant = Tenant.objects.get(schema_name=connection.schema_name)
        try:
            assinatura = MercadoPagoService().confirmar_assinatura(tenant, preapproval_id)
        except PreapprovalInvalidoError as e:
            return erro(str(e), getattr(e, 'code', None), status.HTTP_400_BAD_REQUEST)

        return Response(AssinaturaSerializer(assinatura).data)


class CancelarAssinaturaView(APIView):
    permission_classes = [IsAuthenticated, IsProprietario]

    def post(self, request):
        from tenants.models import Tenant

        tenant = Tenant.objects.get(schema_name=connection.schema_name)
        try:
            assinatura = MercadoPagoService().cancelar_assinatura(tenant)
        except PreapprovalInvalidoError as e:
            return erro(str(e), getattr(e, 'code', None), status.HTTP_400_BAD_REQUEST)

        return Response(AssinaturaSerializer(assinatura).data)


class PagamentosListView(ListAPIView):
    serializer_class = PagamentoSerializer
    permission_classes = [IsAuthenticated]
    def get_queryset(self):
        from tenants.models import Tenant

        tenant = Tenant.objects.get(schema_name=connection.schema_name)
        return Pagamento.objects.filter(assinatura__tenant=tenant).order_by('-data')


class MercadoPagoWebhookView(APIView):
    permission_classes = [AllowAny]
    # Escopo próprio: o Mercado Pago chega de poucos IPs, e o limite de
    # anônimo comum poderia barrar uma rajada legítima de notificações.
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'webhook'

    def post(self, request):
        topico = request.query_params.get('type') or request.query_params.get('topic')
        data_id = request.query_params.get('data.id') or request.query_params.get('id')
        if not topico or not data_id:
            # Notificação fora do formato esperado — confirma recebimento sem processar.
            return Response(status=status.HTTP_200_OK)

        try:
            MercadoPagoService().processar_webhook(
                topico=topico,
                data_id=data_id,
                x_signature=request.headers.get('x-signature', ''),
                x_request_id=request.headers.get('x-request-id', ''),
            )
        except WebhookInvalidoError:
            return erro('Assinatura do webhook inválida.', 'assinatura_invalida', status.HTTP_401_UNAUTHORIZED)

        return Response(status=status.HTTP_200_OK)
