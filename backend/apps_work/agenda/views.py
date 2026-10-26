from datetime import date as date_type
from rest_framework import viewsets, status as drf_status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.plumbing import build_array_type, build_basic_type
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view
from .models import Agendamento, StatusAgendamento
from .serializers import AgendamentoSerializer, PendenciaCobrancaSerializer, SlotSerializer
from .services import (
    AgendamentoService,
    DiasComRegistroService,
    PendenciasCobrancaService,
    SlotsAgendaService,
)
from apps_work.financeiro.serializers import CobrancaSerializer
from core.excecoes import erro
from core.permissions import exigir_poder_cobrar


class PendenciasCobrancaView(APIView):
    @extend_schema(
        responses=PendenciaCobrancaSerializer(many=True),
        summary='Atendimentos passados ainda não cobrados (agenda e kanban)',
    )
    def get(self, request):
        return Response(PendenciasCobrancaService().listar())


class SlotsAgendaView(APIView):
    @extend_schema(
        responses=SlotSerializer(many=True), summary='Horários do dia de um colaborador para um serviço',
        parameters=[
            OpenApiParameter('data', OpenApiTypes.DATE, required=True),
            OpenApiParameter('servico', OpenApiTypes.INT, required=True),
            OpenApiParameter('colaborador', OpenApiTypes.INT, required=True),
        ],
    )
    def get(self, request):
        try:
            data = date_type.fromisoformat(request.query_params['data'])
            servico_id = int(request.query_params['servico'])
            # Obrigatório: a agenda é individual, não existe grade sem dono.
            colaborador_id = int(request.query_params['colaborador'])
        except (KeyError, ValueError):
            return erro('Parâmetros obrigatórios: data (YYYY-MM-DD), servico e colaborador.', 'parametros_invalidos', drf_status.HTTP_400_BAD_REQUEST)

        return Response(SlotsAgendaService().listar(data, servico_id, colaborador_id))


class DiasComRegistroView(APIView):
    @extend_schema(
        responses={200: build_array_type(build_basic_type(OpenApiTypes.DATE))},
        summary='Dias do mês com algum agendamento',
        parameters=[
            OpenApiParameter('ano', OpenApiTypes.INT, required=True),
            OpenApiParameter('mes', OpenApiTypes.INT, required=True, description='1 a 12'),
        ],
    )
    def get(self, request):
        try:
            ano = int(request.query_params['ano'])
            mes = int(request.query_params['mes'])
        except (KeyError, ValueError):
            return erro('Parâmetros obrigatórios: ano e mes (números).', 'parametros_invalidos', drf_status.HTTP_400_BAD_REQUEST)

        if not 1 <= mes <= 12:
            return erro('Mês deve estar entre 1 e 12.', 'mes_invalido', drf_status.HTTP_400_BAD_REQUEST)

        return Response(DiasComRegistroService().listar(ano, mes))


@extend_schema_view(
    list=extend_schema(
        parameters=[
            OpenApiParameter('data', OpenApiTypes.DATE, description='Só os agendamentos deste dia. Cancelados ficam fora da lista.'),
            OpenApiParameter('colaborador', OpenApiTypes.INT),
            OpenApiParameter('cliente', OpenApiTypes.INT),
        ],
    ),
)
class AgendamentoViewSet(viewsets.ModelViewSet):
    serializer_class = AgendamentoSerializer

    def get_queryset(self):
        qs = Agendamento.objects.select_related(
            'cliente', 'colaborador__user'
        ).prefetch_related('servicos__servico', 'pagamentos')

        data = self.request.query_params.get('data')
        colaborador = self.request.query_params.get('colaborador')
        cliente = self.request.query_params.get('cliente')

        if data:
            qs = qs.filter(data_hora__date=data)
        if colaborador:
            qs = qs.filter(colaborador_id=colaborador)
        if cliente:
            qs = qs.filter(cliente_id=cliente)

        if self.action == 'list':
            qs = qs.exclude(status=StatusAgendamento.CANCELADO)

        return qs.order_by('data_hora')

    def perform_create(self, serializer):
        AgendamentoService().verificar_conflito_para_criacao(
            colaborador=serializer.validated_data.get('colaborador'),
            data_hora=serializer.validated_data.get('data_hora'),
            servico_id=serializer.validated_data.get('servico_id'),
        )
        serializer.save()

    def perform_update(self, serializer):
        instance = serializer.instance
        status_anterior = instance.status
        colaborador = serializer.validated_data.get('colaborador', instance.colaborador)
        data_hora = serializer.validated_data.get('data_hora', instance.data_hora)

        # Só revalida o horário quando muda o que define o conflito. Uma
        # edição que mexe apenas no status (ex.: marcar "faltou") não pode
        # ser barrada por um choque que já existia antes dela — foi assim
        # que agendamentos antigos ficaram impossíveis de resolver.
        if colaborador != instance.colaborador or data_hora != instance.data_hora:
            AgendamentoService().verificar_conflito_para_atualizacao(
                agendamento=instance,
                colaborador=colaborador,
                data_hora=data_hora,
            )
        serializer.save()
        AgendamentoService().notificar_mudanca_de_status(serializer.instance, status_anterior)

    @extend_schema(request=CobrancaSerializer, responses=AgendamentoSerializer, summary='Cobrar o atendimento')
    @action(detail=True, methods=['post'])
    def cobrar(self, request, pk=None):
        exigir_poder_cobrar(request)
        agendamento = self.get_object()
        entrada = CobrancaSerializer(data=request.data)
        entrada.is_valid(raise_exception=True)
        dados = entrada.validated_data

        agendamento = AgendamentoService().cobrar(
            agendamento, dados['desconto'], dados['pagamentos'],
            credito_aplicado=dados['credito_aplicado'],
            troco_credito=dados['troco_credito'],
        )

        return Response(AgendamentoSerializer(agendamento).data)
