from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from django.db.models import Q, Prefetch
from .models import Cliente, ObjetoCliente, Pet, Veiculo
from .serializers import ClienteSerializer, ObjetoClienteSerializer, PetSerializer, VeiculoSerializer
from .services import RemocaoClienteService


class ClienteViewSet(viewsets.ModelViewSet):
    serializer_class = ClienteSerializer
    def perform_destroy(self, instance):
        RemocaoClienteService().remover(instance)

    def get_queryset(self):
        objetos_qs = ObjetoCliente.objects.select_related('veiculo', 'pet')
        qs = Cliente.objects.prefetch_related(Prefetch('objetos', queryset=objetos_qs)).filter(visivel=True)
        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(
                Q(nome__icontains=search) |
                Q(telefone__icontains=search) |
                Q(email__icontains=search) |
                Q(cpf__icontains=search)
            )
        return qs.order_by('nome')

    @action(detail=True, methods=['get'], url_path='objetos')
    def objetos(self, request, pk=None):
        cliente = self.get_object()
        qs = ObjetoCliente.objects.filter(cliente=cliente).select_related('veiculo', 'pet')
        serializer = ObjetoClienteSerializer(qs, many=True)
        return Response(serializer.data)


class VeiculoViewSet(viewsets.ModelViewSet):
    serializer_class = VeiculoSerializer

    def get_queryset(self):
        qs = Veiculo.objects.select_related('cliente').all()
        cliente_id = self.request.query_params.get('cliente')
        if cliente_id:
            qs = qs.filter(cliente_id=cliente_id)
        return qs.order_by('modelo')

    def perform_create(self, serializer):
        serializer.save(tipo='veiculo')


class PetViewSet(viewsets.ModelViewSet):
    serializer_class = PetSerializer

    def get_queryset(self):
        qs = Pet.objects.select_related('cliente').all()
        cliente_id = self.request.query_params.get('cliente')
        if cliente_id:
            qs = qs.filter(cliente_id=cliente_id)
        return qs.order_by('nome')

    def perform_create(self, serializer):
        serializer.save(tipo='pet')
