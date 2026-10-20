from datetime import date as date_type
from decimal import Decimal
from rest_framework import viewsets, status as drf_status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import Agendamento
from .serializers import AgendamentoSerializer
from .services import (
    AgendamentoService,
    DiasComRegistroService,
    PendenciasCobrancaService,
    SlotsAgendaService,
)
from core.excecoes import erro


class PendenciasCobrancaView(APIView):
    def get(self, request):
        return Response(PendenciasCobrancaService().listar())


class SlotsAgendaView(APIView):
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
    def get(self, request):
        try:
            ano = int(request.query_params['ano'])
            mes = int(request.query_params['mes'])
        except (KeyError, ValueError):
            return erro('Parâmetros obrigatórios: ano e mes (números).', 'parametros_invalidos', drf_status.HTTP_400_BAD_REQUEST)

        if not 1 <= mes <= 12:
            return erro('Mês deve estar entre 1 e 12.', 'mes_invalido', drf_status.HTTP_400_BAD_REQUEST)

        return Response(DiasComRegistroService().listar(ano, mes))


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
            qs = qs.exclude(status='cancelado')

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

    @action(detail=True, methods=['post'])
    def cobrar(self, request, pk=None):
        agendamento = self.get_object()
        desconto = Decimal(str(request.data.get('desconto', 0)))
        pagamentos = request.data.get('pagamentos', [])
        credito_aplicado = Decimal(str(request.data.get('credito_aplicado', 0)))
        troco_credito = Decimal(str(request.data.get('troco_credito', 0)))

        if not pagamentos:
            return erro('Pelo menos uma forma de pagamento é obrigatória.', 'sem_pagamentos', drf_status.HTTP_400_BAD_REQUEST)

        agendamento = AgendamentoService().cobrar(
            agendamento, desconto, pagamentos,
            credito_aplicado=credito_aplicado,
            troco_credito=troco_credito,
        )

        return Response(AgendamentoSerializer(agendamento).data)
