from datetime import date as date_type
from rest_framework import viewsets, status
from rest_framework import serializers
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.plumbing import build_array_type, build_basic_type
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema, inline_serializer
from core.permissions import IsProprietario
from .models import AtendimentoKanban, EtapaKanban
from .serializers import AtendimentoKanbanSerializer, EtapaKanbanSerializer
from .services import AtendimentoKanbanService, EtapaService, SlotService
from apps_work.financeiro.serializers import CobrancaSerializer
from core.excecoes import erro


class EtapaKanbanViewSet(viewsets.ModelViewSet):
    serializer_class = EtapaKanbanSerializer

    def get_permissions(self):
        if self.action in ('create', 'update', 'partial_update', 'destroy', 'reordenar'):
            return [IsAuthenticated(), IsProprietario()]
        return [IsAuthenticated()]

    def get_queryset(self):
        return EtapaKanban.objects.all()

    @extend_schema(
        request=inline_serializer('ReordenarEtapas', {'ordem': serializers.ListField(child=serializers.IntegerField())}),
        responses={204: None}, summary='Reordenar etapas (ids na nova ordem)',
    )
    @action(detail=False, methods=['post'])
    def reordenar(self, request):
        ordem = request.data.get('ordem', [])
        if not isinstance(ordem, list):
            return erro('ordem deve ser uma lista.', status_code=status.HTTP_400_BAD_REQUEST)
        EtapaService().reordenar(ordem)
        return Response(status=status.HTTP_204_NO_CONTENT)


class AtendimentoKanbanViewSet(viewsets.ModelViewSet):
    serializer_class = AtendimentoKanbanSerializer

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

    @extend_schema(
        request=inline_serializer('MoverAtendimento', {'etapa_id': serializers.IntegerField()}),
        responses={200: AtendimentoKanbanSerializer}, summary='Mover atendimento de etapa',
    )
    @action(detail=True, methods=['post'])
    def mover(self, request, pk=None):
        atendimento = self.get_object()
        etapa_id = request.data.get('etapa_id')
        if not etapa_id:
            return erro('etapa_id é obrigatório.', status_code=status.HTTP_400_BAD_REQUEST)
        try:
            etapa = EtapaKanban.objects.get(pk=etapa_id)
        except EtapaKanban.DoesNotExist:
            return erro('Etapa não encontrada.', status_code=status.HTTP_404_NOT_FOUND)
        atendimento = AtendimentoKanbanService().mover(atendimento, etapa)
        return Response(AtendimentoKanbanSerializer(atendimento).data)

    @extend_schema(request=CobrancaSerializer, responses=AtendimentoKanbanSerializer, summary='Cobrar o atendimento')
    @action(detail=True, methods=['post'])
    def cobrar(self, request, pk=None):
        atendimento = self.get_object()
        entrada = CobrancaSerializer(data=request.data)
        entrada.is_valid(raise_exception=True)
        dados = entrada.validated_data

        atendimento = AtendimentoKanbanService().cobrar(
            atendimento, dados['desconto'], dados['pagamentos'],
            credito_aplicado=dados['credito_aplicado'],
            troco_credito=dados['troco_credito'],
        )

        return Response(AtendimentoKanbanSerializer(atendimento).data)

    @extend_schema(request=None, responses={200: AtendimentoKanbanSerializer}, summary='Desfazer cobrança')
    @action(detail=True, methods=['post'])
    def desfazer_cobranca(self, request, pk=None):
        atendimento = self.get_object()
        if not atendimento.pago:
            return erro('Este atendimento não está marcado como pago.', 'nao_pago', status.HTTP_400_BAD_REQUEST)
        atendimento = AtendimentoKanbanService().desfazer_cobranca(atendimento)
        return Response(AtendimentoKanbanSerializer(atendimento).data)

    @extend_schema(request=None, responses={200: AtendimentoKanbanSerializer}, summary='Marcar falta')
    @action(detail=True, methods=['post'])
    def marcar_falta(self, request, pk=None):
        atendimento = self.get_object()
        atendimento = AtendimentoKanbanService().marcar_falta(atendimento)
        return Response(AtendimentoKanbanSerializer(atendimento).data)

    @extend_schema(request=None, responses={200: AtendimentoKanbanSerializer}, summary='Desfazer falta')
    @action(detail=True, methods=['post'])
    def desfazer_falta(self, request, pk=None):
        atendimento = self.get_object()
        atendimento = AtendimentoKanbanService().desfazer_falta(atendimento)
        return Response(AtendimentoKanbanSerializer(atendimento).data)


class SlotsView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        responses={200: build_array_type(build_basic_type(OpenApiTypes.TIME))},
        summary='Horários de entrada livres no dia (kanban)',
        parameters=[OpenApiParameter('data', OpenApiTypes.DATE, required=True)],
    )
    def get(self, request):
        data_str = request.query_params.get('data')
        if not data_str:
            return erro('Parâmetro data é obrigatório.', status_code=status.HTTP_400_BAD_REQUEST)
        try:
            data = date_type.fromisoformat(data_str)
        except ValueError:
            return erro('Data inválida. Use o formato YYYY-MM-DD.', status_code=status.HTTP_400_BAD_REQUEST)
        slots = SlotService().gerar_slots(data)
        return Response(slots)
