from datetime import date as date_type
from django.db import transaction
from rest_framework import viewsets, status
from rest_framework import serializers
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view, inline_serializer
from core.permissions import IsProprietario
from .models import AtendimentoKanban, EtapaKanban
from .serializers import (
    AjusteDoDiaRequestSerializer, AtendimentoKanbanSerializer, CapacidadeDoDiaSerializer, EtapaKanbanSerializer,
)
from .services import AtendimentoKanbanService, CapacidadeService, EtapaService, SlotService
from apps_work.agenda.serializers import SlotSerializer
from apps_work.financeiro.serializers import CobrancaSerializer
from core.excecoes import erro
from core.permissions import exigir_poder_cobrar


class EtapaKanbanViewSet(viewsets.ModelViewSet):
    serializer_class = EtapaKanbanSerializer

    def get_permissions(self):
        if self.action in ('create', 'update', 'partial_update', 'destroy', 'reordenar', 'pronto'):
            return [IsAuthenticated(), IsProprietario()]
        return [IsAuthenticated()]

    def get_queryset(self):
        return EtapaKanban.objects.all()

    def perform_destroy(self, instance):
        EtapaService().remover(instance)

    @extend_schema(
        request=None, responses={200: EtapaKanbanSerializer},
        summary='Marcar esta etapa como a de pronto (desmarca a anterior)',
    )
    @action(detail=True, methods=['post'])
    def pronto(self, request, pk=None):
        etapa = EtapaService().marcar_pronto(self.get_object())
        return Response(EtapaKanbanSerializer(etapa).data)

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


@extend_schema_view(
    list=extend_schema(
        parameters=[
            OpenApiParameter('data', OpenApiTypes.DATE, description='Só os atendimentos deste dia (o quadro).'),
            OpenApiParameter(
                'cliente', OpenApiTypes.INT,
                description='Só os atendimentos dos objetos deste cliente (o histórico). O avulso não tem cliente '
                            'e fica de fora.',
            ),
            OpenApiParameter('colaborador', OpenApiTypes.INT, description='Só os atendimentos deste profissional.'),
        ],
    ),
)
class AtendimentoKanbanViewSet(viewsets.ModelViewSet):
    serializer_class = AtendimentoKanbanSerializer

    def get_permissions(self):
        return [IsAuthenticated()]

    def get_queryset(self):
        qs = AtendimentoKanban.objects.select_related(
            'etapa', 'objeto__cliente', 'objeto__veiculo', 'objeto__pet', 'servico', 'colaborador__user',
        )
        data = self.request.query_params.get('data')
        cliente = self.request.query_params.get('cliente')
        colaborador = self.request.query_params.get('colaborador')
        if data:
            qs = qs.filter(data=data)
        if cliente:
            qs = qs.filter(objeto__cliente_id=cliente)
        if colaborador:
            qs = qs.filter(colaborador_id=colaborador)
        return qs

    def perform_create(self, serializer):
        # Sem objeto é o avulso: o service exige a identificação.
        objeto = serializer.validated_data.get('objeto')
        atendimento = AtendimentoKanbanService().criar(
            etapa=serializer.validated_data['etapa'],
            objeto_id=objeto.pk if objeto is not None else None,
            servico_id=serializer.validated_data['servico'].pk,
            observacao=serializer.validated_data.get('observacao', ''),
            horario_entrada=serializer.validated_data.get('horario_entrada'),
            data=serializer.validated_data.get('data'),
            colaborador=serializer.validated_data.get('colaborador'),
            ignorar_limite=serializer.validated_data.get('ignorar_limite', False),
            identificacao=serializer.validated_data.get('identificacao', ''),
            minutos_extras=serializer.validated_data.get('minutos_extras', 0),
        )
        serializer.instance = atendimento

    @transaction.atomic
    def perform_update(self, serializer):
        # ignorar_limite não é campo do model: sai antes do save. As regras
        # (avulso, porte, capacidade, pronto) são do service.
        ignorar_limite = serializer.validated_data.pop('ignorar_limite', False)
        AtendimentoKanbanService().conferir_alteracao(serializer.instance, serializer.validated_data, ignorar_limite)
        serializer.save()

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

    @extend_schema(
        request=CobrancaSerializer, responses=AtendimentoKanbanSerializer, summary='Cobrar o atendimento',
        description=(
            'O total é o do serviço mais o acréscimo menos o desconto, e a soma dos pagamentos com o crédito '
            'aplicado tem de bater com ele (400 soma_invalida). `servico_ids` troca o serviço pelo que foi feito '
            'de verdade: um id só (400 um_servico_so), do porte do veículo ou pet (400 servico_de_outro_porte), '
            'existente e ativo (400 servico_invalido). O avulso não aceita crédito nem troco na comanda '
            '(400 avulso_sem_credito).'
        ),
    )
    @action(detail=True, methods=['post'])
    def cobrar(self, request, pk=None):
        exigir_poder_cobrar(request)
        atendimento = self.get_object()
        entrada = CobrancaSerializer(data=request.data)
        entrada.is_valid(raise_exception=True)
        dados = entrada.validated_data

        atendimento = AtendimentoKanbanService().cobrar(
            atendimento, dados['desconto'], dados['pagamentos'],
            credito_aplicado=dados['credito_aplicado'],
            troco_credito=dados['troco_credito'],
            acrescimo=dados['acrescimo'],
            acrescimo_motivo=dados['acrescimo_motivo'],
            servico_ids=dados.get('servico_ids'),
        )

        return Response(AtendimentoKanbanSerializer(atendimento).data)

    @extend_schema(
        request=None, responses={200: AtendimentoKanbanSerializer}, summary='Desfazer cobrança',
        description='Apaga os pagamentos e zera desconto e acréscimo. A troca de serviço feita na cobrança fica.',
    )
    @action(detail=True, methods=['post'])
    def desfazer_cobranca(self, request, pk=None):
        exigir_poder_cobrar(request)
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

    # O mesmo formato da grade da agenda: {horario, disponivel}. Antes o
    # schema prometia uma lista de horas e o cliente Dart quebrava no parse.
    @extend_schema(
        responses=SlotSerializer(many=True),
        summary='Grade de horas de entrada do dia (kanban)',
        parameters=[
            OpenApiParameter('data', OpenApiTypes.DATE, required=True),
            OpenApiParameter(
                'servico', OpenApiTypes.INT,
                description='O serviço que vai entrar: a grade só traz as horas em que a duração dele cabe. '
                            'Sem ele, 30 minutos. Serviço inexistente é 404.',
            ),
            OpenApiParameter(
                'excluir', OpenApiTypes.INT,
                description='O atendimento que está sendo remarcado: a grade não o conta como ocupação.',
            ),
        ],
    )
    def get(self, request):
        data = _data_da_query(request)
        if data is None:
            return erro('Data inválida. Use o formato YYYY-MM-DD.', status_code=status.HTTP_400_BAD_REQUEST)
        servico = _inteiro_da_query(request, 'servico')
        excluir = _inteiro_da_query(request, 'excluir')
        if servico is False or excluir is False:
            return erro('servico e excluir devem ser números.', status_code=status.HTTP_400_BAD_REQUEST)
        return Response(SlotService().gerar_slots(data, servico, excluir))


def _inteiro_da_query(request, nome: str) -> int | None | bool:
    """O parâmetro como inteiro; None quando não veio; False quando veio e
    não é número."""
    valor = request.query_params.get(nome)
    if valor in (None, ''):
        return None
    return int(valor) if valor.isdigit() else False


def _data_da_query(request) -> date_type | None:
    try:
        return date_type.fromisoformat(request.query_params.get('data', ''))
    except ValueError:
        return None


class CapacidadeView(APIView):
    """Quanto cabe num dia da esteira: o padrão da semana ou o ajuste da data
    ("hoje somos 2", "hoje sou só eu"). Ler é de todos; ajustar é do dono."""

    def get_permissions(self):
        if self.request.method in ('PUT', 'DELETE'):
            return [IsAuthenticated(), IsProprietario()]
        return [IsAuthenticated()]

    @extend_schema(
        responses=CapacidadeDoDiaSerializer, summary='Capacidade e ocupação de um dia',
        parameters=[OpenApiParameter('data', OpenApiTypes.DATE, required=True)],
    )
    def get(self, request):
        data = _data_da_query(request)
        if data is None:
            return erro('Data inválida. Use o formato YYYY-MM-DD.', status_code=status.HTTP_400_BAD_REQUEST)
        return Response(CapacidadeDoDiaSerializer(CapacidadeService().do_dia(data)).data)

    @extend_schema(
        request=AjusteDoDiaRequestSerializer, responses=CapacidadeDoDiaSerializer,
        summary='Ajustar a capacidade só desta data',
        parameters=[OpenApiParameter('data', OpenApiTypes.DATE, required=True)],
    )
    def put(self, request):
        data = _data_da_query(request)
        if data is None:
            return erro('Data inválida. Use o formato YYYY-MM-DD.', status_code=status.HTTP_400_BAD_REQUEST)
        entrada = AjusteDoDiaRequestSerializer(data=request.data)
        entrada.is_valid(raise_exception=True)
        info = CapacidadeService().ajustar(
            data, entrada.validated_data.get('capacidade'), entrada.validated_data['vagas'],
        )
        return Response(CapacidadeDoDiaSerializer(info).data)

    @extend_schema(
        request=None, responses=CapacidadeDoDiaSerializer, summary='Voltar a data ao padrão da semana',
        parameters=[OpenApiParameter('data', OpenApiTypes.DATE, required=True)],
    )
    def delete(self, request):
        data = _data_da_query(request)
        if data is None:
            return erro('Data inválida. Use o formato YYYY-MM-DD.', status_code=status.HTTP_400_BAD_REQUEST)
        return Response(CapacidadeDoDiaSerializer(CapacidadeService().desfazer_ajuste(data)).data)
