from rest_framework import viewsets
from rest_framework import serializers
from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import Notificacao
from .serializers import NotificacaoSerializer
from core.openapi import MensagemSerializer


class NotificacaoViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = NotificacaoSerializer
    permission_classes = [IsAuthenticated]
    def get_queryset(self):
        return Notificacao.objects.all()

    @extend_schema(
        responses={200: inline_serializer('NotificacoesNaoLidas', {'total': serializers.IntegerField()})},
        summary='Total de notificações não lidas',
    )
    @action(detail=False, methods=['get'], url_path='nao-lidas')
    def nao_lidas(self, request):
        total = Notificacao.objects.filter(lida=False).count()
        return Response({'total': total})

    @extend_schema(request=None, responses={200: NotificacaoSerializer}, summary='Marcar notificação como lida')
    @action(detail=True, methods=['post'], url_path='marcar-lida')
    def marcar_lida(self, request, pk=None):
        notificacao = self.get_object()
        if not notificacao.lida:
            notificacao.lida = True
            notificacao.save(update_fields=['lida'])
        return Response(NotificacaoSerializer(notificacao).data)

    @extend_schema(request=None, responses={200: MensagemSerializer}, summary='Marcar todas como lidas')
    @action(detail=False, methods=['post'], url_path='marcar-todas-lidas')
    def marcar_todas_lidas(self, request):
        Notificacao.objects.filter(lida=False).update(lida=True)
        return Response({'detail': 'Todas as notificações foram marcadas como lidas.'})
