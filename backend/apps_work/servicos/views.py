from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from django.db.models import Q
from core.permissions import IsProprietario
from .models import Servico
from .serializers import ServicoSerializer


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

        return qs.order_by('nome')
