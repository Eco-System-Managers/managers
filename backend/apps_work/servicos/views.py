from django.db.models import Q
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from core.permissions import IsProprietario
from .models import Servico
from .serializers import ServicoSerializer


@extend_schema_view(
    list=extend_schema(
        parameters=[
            OpenApiParameter('search', OpenApiTypes.STR, description='Busca em nome e descrição.'),
            OpenApiParameter(
                'ativo', OpenApiTypes.BOOL,
                description='`true` só os ativos, `false` só os inativos; sem o filtro, todos.',
            ),
            OpenApiParameter('colaborador', OpenApiTypes.INT, description='Só os serviços que este colaborador executa.'),
            OpenApiParameter(
                'porte', OpenApiTypes.STR,
                description='Só os que servem para este porte: os dele e os sem porte (valem para qualquer um).',
            ),
        ],
    ),
)
class ServicoViewSet(viewsets.ModelViewSet):
    serializer_class = ServicoSerializer

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsAuthenticated(), IsProprietario()]
        return [IsAuthenticated()]

    def get_queryset(self):
        qs = Servico.objects.prefetch_related('colaboradores').all()

        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(Q(nome__icontains=search) | Q(descricao__icontains=search))

        ativo = self.request.query_params.get('ativo')
        if ativo is not None:
            qs = qs.filter(ativo=ativo.lower() == 'true')

        colaborador = self.request.query_params.get('colaborador')
        if colaborador:
            qs = qs.filter(colaboradores__id=colaborador)

        porte = self.request.query_params.get('porte')
        if porte:
            qs = qs.filter(Q(porte='') | Q(porte=porte))

        return qs.order_by('nome')
