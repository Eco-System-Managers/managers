from django.conf import settings
from django.db import connection
from django.http import HttpResponseRedirect
from rest_framework import status
from rest_framework.generics import ListAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.utils import extend_schema

from core.permissions import IsProprietario
from .models import Assinatura, PagamentoAssinatura, Plano
from .serializers import (
    AssinaturaSerializer, ConfirmarAssinaturaSerializer, LinkAssinaturaSerializer, PagamentoAssinaturaSerializer,
)
from .services import (
    AssinaturaGatewayError,
    AssinaturaInvalidaError,
    gateway_de_pagamento,
    MercadoPagoGateway,
    WebhookInvalidoError,
)
from core.excecoes import erro
from core.links import link_retorno_pagamento


def _assinatura_em_breve():
    """A trava enquanto assinar pelo app não está liberado (ASSINATURA_ABERTA).
    Fica no servidor, e não só na tela: um app antigo ou um pedido à mão não
    passa por ela."""
    if settings.ASSINATURA_ABERTA:
        return None
    return erro('A assinatura pelo app chega em breve.', 'assinatura_em_breve', status.HTTP_403_FORBIDDEN)


class MinhaAssinaturaView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(responses=AssinaturaSerializer, summary='Assinatura do negócio')
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

    @extend_schema(request=None, responses=LinkAssinaturaSerializer, summary='Link do checkout do plano padrão')
    def post(self, request):
        if (bloqueio := _assinatura_em_breve()) is not None:
            return bloqueio

        plano = Plano.objects.filter(nome=settings.PLANO_PADRAO, ativo=True).first()
        if plano is None:
            return erro('O plano de assinatura não está configurado.', 'plano_nao_configurado')

        try:
            link = gateway_de_pagamento().obter_link_assinatura(plano)
        except AssinaturaInvalidaError as e:
            return erro(str(e), 'plano_nao_configurado')

        return Response({'link_checkout': link})


class RetornoCheckoutView(APIView):
    """Recebe o redirect do Mercado Pago após o checkout (back_url) e repassa
    pro frontend com a mesma query string — não interpreta nada aqui, só
    resolve o back_url precisar ser um domínio público (https/ngrok em dev,
    o domínio real em produção), diferente do frontend, que pode estar em
    localhost em dev."""

    permission_classes = [AllowAny]

    @extend_schema(
        exclude=True,  # back_url do Mercado Pago: quem chama é o navegador, não o app
    )
    def get(self, request):
        query = request.META.get('QUERY_STRING', '')
        return HttpResponseRedirect(link_retorno_pagamento(query))


class ConfirmarAssinaturaView(APIView):
    permission_classes = [IsAuthenticated, IsProprietario]

    @extend_schema(
        request=ConfirmarAssinaturaSerializer, responses=AssinaturaSerializer,
        summary='Vincular ao negócio a assinatura feita no checkout do gateway',
    )
    def post(self, request):
        if (bloqueio := _assinatura_em_breve()) is not None:
            return bloqueio

        id_externo = request.data.get('id_externo')
        if not id_externo:
            return erro('id_externo é obrigatório.', 'parametros_invalidos')

        from tenants.models import Tenant

        tenant = Tenant.objects.get(schema_name=connection.schema_name)
        try:
            assinatura = gateway_de_pagamento().confirmar_assinatura(tenant, id_externo)
        except AssinaturaGatewayError as e:
            return erro(str(e), 'assinatura_recusada')

        return Response(AssinaturaSerializer(assinatura).data)


class CancelarAssinaturaView(APIView):
    permission_classes = [IsAuthenticated, IsProprietario]

    @extend_schema(request=None, responses=AssinaturaSerializer, summary='Cancelar a assinatura')
    def post(self, request):
        from tenants.models import Tenant

        tenant = Tenant.objects.get(schema_name=connection.schema_name)
        try:
            assinatura = gateway_de_pagamento().cancelar_assinatura(tenant)
        except AssinaturaGatewayError as e:
            return erro(str(e), 'assinatura_recusada')

        return Response(AssinaturaSerializer(assinatura).data)


class PagamentosListView(ListAPIView):
    serializer_class = PagamentoAssinaturaSerializer
    permission_classes = [IsAuthenticated]
    def get_queryset(self):
        from tenants.models import Tenant

        tenant = Tenant.objects.get(schema_name=connection.schema_name)
        return PagamentoAssinatura.objects.filter(assinatura__tenant=tenant).order_by('-data')


class MercadoPagoWebhookView(APIView):
    permission_classes = [AllowAny]
    # Escopo próprio: o Mercado Pago chega de poucos IPs, e o limite de
    # anônimo comum poderia barrar uma rajada legítima de notificações.
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'webhook'

    @extend_schema(exclude=True)  # chamado pelo Mercado Pago, não pelo app
    def post(self, request):
        topico = request.query_params.get('type') or request.query_params.get('topic')
        data_id = request.query_params.get('data.id') or request.query_params.get('id')
        if not topico or not data_id:
            # Notificação fora do formato esperado — confirma recebimento sem processar.
            return Response(status=status.HTTP_200_OK)

        try:
            MercadoPagoGateway().processar_webhook(
                topico=topico,
                data_id=data_id,
                x_signature=request.headers.get('x-signature', ''),
                x_request_id=request.headers.get('x-request-id', ''),
            )
        except WebhookInvalidoError:
            return erro('Assinatura do webhook inválida.', 'assinatura_invalida', status.HTTP_401_UNAUTHORIZED)

        return Response(status=status.HTTP_200_OK)
