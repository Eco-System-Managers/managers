from datetime import date as date_type
from django.db.models import Q
from rest_framework import mixins, viewsets, status as drf_status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.plumbing import build_array_type, build_basic_type
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view
from .models import Agendamento, Bloqueio, StatusAgendamento
from .serializers import AgendamentoSerializer, BloqueioSerializer, PendenciaCobrancaSerializer, SlotSerializer
from .services import (
    AgendamentoService,
    BloqueioService,
    DiasComRegistroService,
    PendenciasCobrancaService,
    SlotsAgendaService,
)
from apps_work.financeiro.serializers import CobrancaSerializer
from core.excecoes import ErroDeNegocio, erro
from core.permissions import eh_proprietario, exigir_poder_bloquear, exigir_poder_cobrar


def exigir_poder_bloquear_em(request, colaborador_id: int | None) -> None:
    """Quem pode criar ou excluir um bloqueio. Sem colaborador é o do negócio
    inteiro — fecha a agenda de todos e a esteira —, então só o dono (403
    sem_permissao). Com colaborador vale a regra da agenda individual
    (`exigir_poder_bloquear`)."""
    if colaborador_id is None:
        if not eh_proprietario(request):
            raise ErroDeNegocio('Só o proprietário fecha horários do negócio.', 'sem_permissao', 403)
        return
    exigir_poder_bloquear(request, colaborador_id)


@extend_schema_view(
    list=extend_schema(
        summary='Bloqueios da agenda e do negócio',
        parameters=[
            OpenApiParameter('data', OpenApiTypes.DATE, description='Só os que valem neste dia (o fixo vale do início em diante).'),
            OpenApiParameter(
                'colaborador', OpenApiTypes.INT,
                description='Os que valem na agenda deste profissional: os dele e os do negócio (colaborador nulo).',
            ),
        ],
    ),
    create=extend_schema(
        summary='Bloquear um período da agenda ou do negócio',
        description=(
            'Com `colaborador`, a agenda de um profissional: o dono bloqueia a de qualquer um; o parceiro, só a '
            'própria (403 sem_permissao_bloquear). Sem `colaborador` (nulo ou omitido), o negócio inteiro fecha '
            'no período — a agenda de todos e a esteira —, e só o proprietário faz isso (403 sem_permissao). '
            'Recusado com 400 bloqueio_com_cliente quando há atendimento marcado dentro do período.'
        ),
    ),
    destroy=extend_schema(
        summary='Excluir um bloqueio',
        description='O do negócio (colaborador nulo) só o proprietário exclui (403 sem_permissao).',
    ),
)
class BloqueioViewSet(mixins.ListModelMixin, mixins.CreateModelMixin, mixins.DestroyModelMixin, viewsets.GenericViewSet):
    """Sem editar: para mudar um bloqueio, a pessoa exclui e cria de novo."""

    serializer_class = BloqueioSerializer

    def get_queryset(self):
        data = self.request.query_params.get('data')
        colaborador = self.request.query_params.get('colaborador')

        try:
            qs = BloqueioService().do_dia(date_type.fromisoformat(data)) if data else Bloqueio.objects.all()
            if colaborador:
                # o fechamento do negócio vale na agenda de todos: entra junto
                qs = qs.filter(Q(colaborador_id=int(colaborador)) | Q(colaborador__isnull=True))
        except ValueError:
            raise ErroDeNegocio('Parâmetros inválidos: data (YYYY-MM-DD) e colaborador (número).', 'parametros_invalidos')
        return qs.select_related('colaborador__user')

    def perform_create(self, serializer):
        colaborador = serializer.validated_data.get('colaborador')
        exigir_poder_bloquear_em(self.request, colaborador.pk if colaborador else None)
        serializer.instance = BloqueioService().criar(**serializer.validated_data)

    def perform_destroy(self, instance):
        exigir_poder_bloquear_em(self.request, instance.colaborador_id)
        instance.delete()


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

    @extend_schema(
        request=CobrancaSerializer, responses=AgendamentoSerializer, summary='Cobrar o atendimento',
        description=(
            'Conclui o agendamento. O total é o dos serviços mais o acréscimo menos o desconto, e a soma dos '
            'pagamentos com o crédito aplicado tem de bater com ele (400 soma_invalida). `servico_ids` troca os '
            'serviços pelos que foram feitos de verdade, com o preço atual de cada um (400 servico_invalido se '
            'algum não existe ou está inativo).'
        ),
    )
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
            acrescimo=dados['acrescimo'],
            acrescimo_motivo=dados['acrescimo_motivo'],
            servico_ids=dados.get('servico_ids'),
        )

        return Response(AgendamentoSerializer(agendamento).data)
