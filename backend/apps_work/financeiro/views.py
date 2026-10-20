from datetime import date
from decimal import Decimal
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import status as http_status
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema

from core.permissions import IsProprietario
from apps_work.clientes.models import Cliente
from .models import Despesa, TipoTransacao, TransacaoCredito
from .serializers import (
    CaixaSerializer, DespesaSerializer, ResumoDespesasSerializer, SaldoClienteSerializer,
    TransacaoCreditoSerializer,
)
from .services import CaixaService, DespesaService
from core.excecoes import ErroDeNegocio, erro


class SaldoClienteView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(responses=SaldoClienteSerializer, summary='Saldo de crédito e extrato do cliente')
    def get(self, request, cliente_id):
        if not Cliente.objects.filter(id=cliente_id).exists():
            return erro('Cliente não encontrado.', status_code=http_status.HTTP_404_NOT_FOUND)

        transacoes = list(TransacaoCredito.objects.filter(cliente_id=cliente_id))
        saldo = sum(
            (t.valor if t.tipo == TipoTransacao.CREDITO else -t.valor) for t in transacoes
        ) or Decimal('0')
        return Response({
            'saldo': str(saldo.quantize(Decimal('0.01'))),
            'transacoes': TransacaoCreditoSerializer(transacoes, many=True).data,
        })


class CaixaView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        responses=CaixaSerializer, summary='Fechamento de caixa do período',
        parameters=[
            OpenApiParameter('data_inicio', OpenApiTypes.DATE, description='Padrão: hoje.'),
            OpenApiParameter('data_fim', OpenApiTypes.DATE, description='Padrão: hoje.'),
            OpenApiParameter('colaborador', OpenApiTypes.INT, description='Filtra pelo colaborador (exclui o kanban).'),
        ],
    )
    def get(self, request):
        data_inicio_str = request.query_params.get('data_inicio')
        data_fim_str = request.query_params.get('data_fim')
        try:
            data_inicio = date.fromisoformat(data_inicio_str) if data_inicio_str else date.today()
            data_fim = date.fromisoformat(data_fim_str) if data_fim_str else date.today()
        except ValueError:
            return erro('Data inválida.', status_code=http_status.HTTP_400_BAD_REQUEST)

        colaborador_str = request.query_params.get('colaborador')
        colaborador_id = None
        if colaborador_str:
            try:
                colaborador_id = int(colaborador_str)
            except ValueError:
                return erro('Colaborador inválido.', status_code=http_status.HTTP_400_BAD_REQUEST)

        dados = CaixaService().obter_dados(data_inicio, data_fim, colaborador_id)
        return Response(dados)


class DespesaViewSet(viewsets.ModelViewSet):
    serializer_class = DespesaSerializer
    permission_classes = [IsProprietario]

    def get_queryset(self):
        qs = Despesa.objects.all()
        params = self.request.query_params

        data_inicio = params.get('data_inicio')
        data_fim = params.get('data_fim')
        categoria = params.get('categoria')
        try:
            if data_inicio:
                qs = qs.filter(data__gte=date.fromisoformat(data_inicio))
            if data_fim:
                qs = qs.filter(data__lte=date.fromisoformat(data_fim))
        except ValueError:
            # Antes devolvia página vazia, indistinguível de "sem despesas".
            raise ErroDeNegocio('Data inválida. Use o formato YYYY-MM-DD.', 'data_invalida')
        if categoria:
            qs = qs.filter(categoria=categoria)

        return qs.order_by('-data', '-criado_em')

    @extend_schema(
        responses=ResumoDespesasSerializer, summary='Total de despesas por categoria',
        parameters=[
            OpenApiParameter('data_inicio', OpenApiTypes.DATE, description='Padrão: hoje.'),
            OpenApiParameter('data_fim', OpenApiTypes.DATE, description='Padrão: hoje.'),
        ],
    )
    @action(detail=False, methods=['get'], url_path='resumo')
    def resumo(self, request):
        data_inicio_str = request.query_params.get('data_inicio')
        data_fim_str = request.query_params.get('data_fim')
        try:
            data_inicio = date.fromisoformat(data_inicio_str) if data_inicio_str else date.today()
            data_fim = date.fromisoformat(data_fim_str) if data_fim_str else date.today()
        except ValueError:
            return erro('Data inválida.', status_code=http_status.HTTP_400_BAD_REQUEST)

        return Response(DespesaService().resumo(data_inicio, data_fim))
