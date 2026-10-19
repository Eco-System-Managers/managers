from datetime import date as date_type
from decimal import Decimal
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.pagination import PageNumberPagination
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from core.permissions import IsProprietario
from .models import AtendimentoKanban, EtapaKanban
from .serializers import AtendimentoKanbanSerializer, EtapaKanbanSerializer
from .services import AtendimentoKanbanService, EtapaService, SlotService


class EtapaKanbanViewSet(viewsets.ModelViewSet):
    serializer_class = EtapaKanbanSerializer

    def get_permissions(self):
        if self.action in ('create', 'update', 'partial_update', 'destroy', 'reordenar'):
            return [IsAuthenticated(), IsProprietario()]
        return [IsAuthenticated()]

    def get_queryset(self):
        return EtapaKanban.objects.all()

    @action(detail=False, methods=['post'])
    def reordenar(self, request):
        ordem = request.data.get('ordem', [])
        if not isinstance(ordem, list):
            return Response({'detail': 'ordem deve ser uma lista.'}, status=status.HTTP_400_BAD_REQUEST)
        EtapaService().reordenar(ordem)
        return Response(status=status.HTTP_204_NO_CONTENT)


class AtendimentoKanbanPagination(PageNumberPagination):
    page_size = 20


class AtendimentoKanbanViewSet(viewsets.ModelViewSet):
    serializer_class = AtendimentoKanbanSerializer
    pagination_class = AtendimentoKanbanPagination

    def paginate_queryset(self, queryset):
        """O quadro do dia sai inteiro; o resto vem paginado.

        Mesma razao da agenda: o kanban monta as colunas com todos os
        atendimentos daquela data, e uma pagina 2 que nao chega faria card
        sumir do quadro sem erro nenhum. Ja o historico por cliente nao tem
        teto e cresce a cada visita.
        """
        if self.request.query_params.get('data'):
            return None
        return super().paginate_queryset(queryset)

    def get_permissions(self):
        return [IsAuthenticated()]

    def get_queryset(self):
        qs = AtendimentoKanban.objects.select_related(
            'etapa', 'objeto__cliente', 'objeto__veiculo', 'objeto__pet', 'servico'
        )
        data = self.request.query_params.get('data')
        cliente = self.request.query_params.get('cliente')
        if data:
            qs = qs.filter(data=data)
        if cliente:
            qs = qs.filter(objeto__cliente_id=cliente)
        return qs

    def perform_create(self, serializer):
        atendimento = AtendimentoKanbanService().criar(
            etapa=serializer.validated_data['etapa'],
            objeto_id=serializer.validated_data['objeto'].pk,
            servico_id=serializer.validated_data['servico'].pk,
            observacao=serializer.validated_data.get('observacao', ''),
            horario_entrada=serializer.validated_data.get('horario_entrada'),
            data=serializer.validated_data.get('data'),
        )
        serializer.instance = atendimento

    @action(detail=True, methods=['post'])
    def mover(self, request, pk=None):
        atendimento = self.get_object()
        etapa_id = request.data.get('etapa_id')
        if not etapa_id:
            return Response({'detail': 'etapa_id é obrigatório.'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            etapa = EtapaKanban.objects.get(pk=etapa_id)
        except EtapaKanban.DoesNotExist:
            return Response({'detail': 'Etapa não encontrada.'}, status=status.HTTP_404_NOT_FOUND)
        atendimento = AtendimentoKanbanService().mover(atendimento, etapa)
        return Response(AtendimentoKanbanSerializer(atendimento).data)

    @action(detail=True, methods=['post'])
    def cobrar(self, request, pk=None):
        atendimento = self.get_object()
        desconto = Decimal(str(request.data.get('desconto', 0)))
        pagamentos = request.data.get('pagamentos', [])
        credito_aplicado = Decimal(str(request.data.get('credito_aplicado', 0)))
        troco_credito = Decimal(str(request.data.get('troco_credito', 0)))

        if not pagamentos:
            return Response(
                {'detail': 'Pelo menos uma forma de pagamento é obrigatória.', 'code': 'sem_pagamentos'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            atendimento = AtendimentoKanbanService().cobrar(
                atendimento, desconto, pagamentos,
                credito_aplicado=credito_aplicado,
                troco_credito=troco_credito,
            )
        except ValidationError as e:
            return Response(e.detail, status=status.HTTP_400_BAD_REQUEST)

        return Response(AtendimentoKanbanSerializer(atendimento).data)

    @action(detail=True, methods=['post'])
    def desfazer_cobranca(self, request, pk=None):
        atendimento = self.get_object()
        if not atendimento.pago:
            return Response(
                {'detail': 'Este atendimento não está marcado como pago.', 'code': 'nao_pago'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        atendimento = AtendimentoKanbanService().desfazer_cobranca(atendimento)
        return Response(AtendimentoKanbanSerializer(atendimento).data)

    @action(detail=True, methods=['post'])
    def marcar_falta(self, request, pk=None):
        atendimento = self.get_object()
        try:
            atendimento = AtendimentoKanbanService().marcar_falta(atendimento)
        except ValidationError as e:
            return Response(e.detail, status=status.HTTP_400_BAD_REQUEST)
        return Response(AtendimentoKanbanSerializer(atendimento).data)

    @action(detail=True, methods=['post'])
    def desfazer_falta(self, request, pk=None):
        atendimento = self.get_object()
        atendimento = AtendimentoKanbanService().desfazer_falta(atendimento)
        return Response(AtendimentoKanbanSerializer(atendimento).data)


class SlotsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        data_str = request.query_params.get('data')
        if not data_str:
            return Response(
                {'detail': 'Parâmetro data é obrigatório.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            data = date_type.fromisoformat(data_str)
        except ValueError:
            return Response(
                {'detail': 'Data inválida. Use o formato YYYY-MM-DD.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        slots = SlotService().gerar_slots(data)
        return Response(slots)
