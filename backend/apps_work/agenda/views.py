from datetime import date as date_type
from django.db.models import Q
from rest_framework import mixins, viewsets, status as drf_status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.plumbing import build_array_type, build_basic_type
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view
from .models import Agendamento, Bloqueio, StatusAgendamento
from .serializers import (
    AgendamentoSerializer, BloqueioSerializer, PendenciaCobrancaSerializer, ServicosDoAgendamentoSerializer,
    SlotSerializer,
)
from .services import (
    AgendamentoService,
    BloqueioService,
    DiasComRegistroService,
    PendenciasCobrancaService,
    SlotsAgendaService,
)
from apps_work.financeiro.serializers import CobrancaSerializer
from core.excecoes import ErroDeNegocio, erro
from core.permissions import (
    NaoEhColaboradorDaEsteira, eh_esteira, eh_proprietario_ou_parceiro_da_esteira,
    exigir_nao_ser_colaborador_da_esteira, exigir_poder_bloquear, exigir_poder_cobrar,
)


def exigir_poder_bloquear_em(request, colaborador_id: int | None) -> None:
    """Quem pode criar ou excluir um bloqueio. Sem colaborador é o do negócio
    inteiro — fecha a agenda de todos e a esteira —: o dono e, na esteira, o
    parceiro, que toca o negócio com ele (403 sem_permissao para os outros).
    Com colaborador vale a regra da agenda individual
    (`exigir_poder_bloquear`)."""
    if colaborador_id is None:
        if not eh_proprietario_ou_parceiro_da_esteira(request):
            raise ErroDeNegocio('Você não pode fechar horários do negócio.', 'sem_permissao', 403)
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
            'própria (403 sem_permissao_bloquear). Na esteira não há agenda por profissional: com `colaborador` '
            'é 400 bloqueio_individual_na_esteira. Sem `colaborador` (nulo ou omitido), o negócio inteiro fecha '
            'no período — a agenda de todos e a esteira —: o proprietário e, na esteira, o parceiro (403 '
            'sem_permissao para os outros). Recusado com 400 bloqueio_com_cliente quando há atendimento marcado '
            'dentro do período.'
        ),
    ),
    destroy=extend_schema(
        summary='Excluir um bloqueio',
        description='O do negócio (colaborador nulo) é do proprietário e, na esteira, do parceiro (403 sem_permissao).',
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
        if eh_esteira(self.request):
            # na esteira só existe o bloqueio do negócio: quem não pode fechá-lo
            # é 403 antes de tudo, e ninguém tem agenda própria para fechar
            exigir_poder_bloquear_em(self.request, None)
            if colaborador is not None:
                raise ErroDeNegocio(
                    'Na esteira não há agenda por profissional: feche o horário do negócio inteiro.',
                    'bloqueio_individual_na_esteira',
                )
        else:
            exigir_poder_bloquear_em(self.request, colaborador.pk if colaborador else None)
        serializer.instance = BloqueioService().criar(**serializer.validated_data)

    def perform_destroy(self, instance):
        exigir_poder_bloquear_em(self.request, instance.colaborador_id)
        instance.delete()


class PendenciasCobrancaView(APIView):
    @extend_schema(
        responses=PendenciaCobrancaSerializer(many=True),
        summary='Atendimentos passados ainda não cobrados (agenda e kanban)',
        description='Para quem cobra: o colaborador comum da esteira recebe 403 sem_permissao.',
    )
    def get(self, request):
        # pendência de cobrança é assunto de quem cobra
        exigir_nao_ser_colaborador_da_esteira(request)
        return Response(PendenciasCobrancaService().listar())


class SlotsAgendaView(APIView):
    # a agenda individual não é do colaborador comum da esteira
    permission_classes = [IsAuthenticated, NaoEhColaboradorDaEsteira]

    @extend_schema(
        responses=SlotSerializer(many=True), summary='Horários do dia de um colaborador para um ou mais serviços',
        parameters=[
            OpenApiParameter('data', OpenApiTypes.DATE, required=True),
            OpenApiParameter(
                'servico', OpenApiTypes.INT, required=True, many=True, explode=True,
                description='Repetido para vários serviços (`servico=1&servico=2`): a grade usa a soma das durações.',
            ),
            OpenApiParameter('colaborador', OpenApiTypes.INT, required=True),
        ],
    )
    def get(self, request):
        try:
            data = date_type.fromisoformat(request.query_params['data'])
            servico_ids = [int(i) for i in request.query_params.getlist('servico')]
            # Obrigatório: a agenda é individual, não existe grade sem dono.
            colaborador_id = int(request.query_params['colaborador'])
            if not servico_ids:
                raise ValueError
        except (KeyError, ValueError):
            return erro('Parâmetros obrigatórios: data (YYYY-MM-DD), servico e colaborador.', 'parametros_invalidos', drf_status.HTTP_400_BAD_REQUEST)

        return Response(SlotsAgendaService().listar(data, servico_ids, colaborador_id))


class DiasComRegistroView(APIView):
    permission_classes = [IsAuthenticated, NaoEhColaboradorDaEsteira]

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
    # a agenda por horário não é do colaborador comum da esteira: ele só move
    # os cards do quadro (receber, ver telefone e valores e cobrar por aqui
    # seria uma porta lateral; 403 `sem_permissao`)
    permission_classes = [IsAuthenticated, NaoEhColaboradorDaEsteira]

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
            servicos=serializer.servicos,
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
        request=ServicosDoAgendamentoSerializer, responses=AgendamentoSerializer,
        summary='Mudar os serviços antes do atendimento',
        description=(
            'Substitui a lista de serviços de um agendamento agendado ou confirmado (senão, 400 '
            'agendamento_encerrado: o acerto é na cobrança). Quem fica mantém o preço congelado; quem entra vem '
            'com o preço atual. A duração nova tem de caber na agenda do profissional (400 horario_conflito, '
            'horario_bloqueado). Inexistente ou inativo: 400 servico_invalido.'
        ),
    )
    @action(detail=True, methods=['put'])
    def servicos(self, request, pk=None):
        agendamento = self.get_object()
        entrada = ServicosDoAgendamentoSerializer(data=request.data)
        entrada.is_valid(raise_exception=True)

        agendamento = AgendamentoService().trocar_servicos(agendamento, entrada.validated_data['servico_ids'])

        return Response(AgendamentoSerializer(agendamento).data)

    @extend_schema(
        request=CobrancaSerializer, responses=AgendamentoSerializer, summary='Cobrar o atendimento',
        description=(
            'Conclui o agendamento. O total é o dos serviços mais o acréscimo menos o desconto, e a soma dos '
            'pagamentos com o crédito aplicado tem de bater com ele (400 soma_invalida). `servico_ids` troca os '
            'serviços pelos que foram feitos de verdade: quem fica mantém o preço congelado, quem entra vem com o '
            'atual (400 servico_invalido se algum não existe ou está inativo).'
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
