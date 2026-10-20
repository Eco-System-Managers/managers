from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from django.db.models import Q
from django.utils import timezone
from apps_work.autenticacao.views import responder_sessao
from core.permissions import IsProprietario
from .models import Colaborador, ConviteColaborador
from .serializers import ColaboradorSerializer, ConviteColaboradorSerializer
from .services import AceitarConviteService, ColaboradorService, ConviteService
from core.excecoes import erro


class ColaboradorViewSet(viewsets.ModelViewSet):
    serializer_class = ColaboradorSerializer

    _ACOES_DO_PROPRIETARIO = {'update', 'partial_update', 'destroy', 'remover', 'ativar', 'desativar'}

    def get_permissions(self):
        if self.action in self._ACOES_DO_PROPRIETARIO:
            return [IsAuthenticated(), IsProprietario()]
        return [IsAuthenticated()]

    def get_queryset(self):
        qs = Colaborador.objects.select_related('user').all()
        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(
                Q(user__first_name__icontains=search) |
                Q(user__last_name__icontains=search) |
                Q(user__email__icontains=search)
            )
        return qs.order_by('-role', 'user__first_name', 'user__last_name')

    def destroy(self, request, *args, **kwargs):
        return self.desativar(request, *args, **kwargs)

    @action(detail=True, methods=['post'], url_path='desativar')
    def desativar(self, request, pk=None):
        colaborador = self.get_object()
        try:
            ColaboradorService().desativar(colaborador)
        except ValueError as e:
            return erro(str(e), getattr(e, 'code', None), status.HTTP_400_BAD_REQUEST)
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=['post'], url_path='ativar')
    def ativar(self, request, pk=None):
        colaborador = self.get_object()
        ColaboradorService().reativar(colaborador)
        return Response(ColaboradorSerializer(colaborador).data)

    @action(detail=True, methods=['get'], url_path='agendamentos-pendentes')
    def agendamentos_pendentes(self, request, pk=None):
        colaborador = self.get_object()
        return Response(ColaboradorService().tem_agendamentos_pendentes(colaborador))

    @action(detail=False, methods=['get'], url_path='me')
    def me(self, request):
        try:
            colaborador = request.user.colaborador
        except Colaborador.DoesNotExist:
            return erro('Usuário sem perfil de colaborador.', 'sem_colaborador', status.HTTP_404_NOT_FOUND)
        return Response(ColaboradorSerializer(colaborador).data)

    @action(detail=True, methods=['delete'], url_path='remover')
    def remover(self, request, pk=None):
        colaborador = self.get_object()
        try:
            ColaboradorService().remover(colaborador)
        except ValueError as e:
            return erro(str(e), getattr(e, 'code', None), status.HTTP_400_BAD_REQUEST)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ConviteColaboradorViewSet(viewsets.ModelViewSet):
    serializer_class = ConviteColaboradorSerializer

    def get_authenticators(self):
        if getattr(self, 'action', None) in ('aceitar_por_token', 'info'):
            return []
        return super().get_authenticators()

    def get_permissions(self):
        if self.action in ('aceitar_por_token', 'info'):
            return [AllowAny()]
        if self.action in ('create', 'destroy'):
            return [IsAuthenticated(), IsProprietario()]
        return [IsAuthenticated()]

    def get_throttles(self):
        # Convidar revela se um e-mail já tem conta na plataforma — limitar
        # a taxa evita que isso vire um oráculo de enumeração de e-mails.
        if self.action == 'create':
            self.throttle_scope = 'convite_criar'
            return [ScopedRateThrottle()]
        return super().get_throttles()

    def get_queryset(self):
        return ConviteColaborador.objects.filter(
            aceito=False, expira_em__gt=timezone.now(),
        ).order_by('-criado_em')

    def perform_destroy(self, instance):
        from tenants.models import ConviteIndex
        ConviteIndex.objects.filter(token=instance.token).delete()
        instance.delete()

    def perform_create(self, serializer):
        from django.db import connection
        from tenants.models import Tenant
        tenant = Tenant.objects.get(schema_name=connection.schema_name)
        # Regra violada levanta ErroDeNegocio, que o handler transforma em 400.
        serializer.instance = ConviteService().criar_e_enviar(
            nome=serializer.validated_data.get('nome', ''),
            email=serializer.validated_data['email'],
            tenant_nome=tenant.name,
        )

    @action(detail=False, methods=['get'], url_path=r'info/(?P<token>[^/.]+)', permission_classes=[AllowAny])
    def info(self, request, token=None):
        from django.db import connection
        from tenants.models import ConviteIndex, Tenant

        try:
            index = ConviteIndex.objects.get(token=token)
        except ConviteIndex.DoesNotExist:
            return erro('Convite não encontrado.', status_code=status.HTTP_404_NOT_FOUND)

        try:
            tenant = Tenant.objects.get(schema_name=index.schema_name)
        except Tenant.DoesNotExist:
            return erro('Convite não encontrado.', status_code=status.HTTP_404_NOT_FOUND)

        connection.set_tenant(tenant)

        try:
            convite = ConviteColaborador.objects.get(token=token, aceito=False)
        except ConviteColaborador.DoesNotExist:
            return erro('Convite não encontrado ou já utilizado.', status_code=status.HTTP_404_NOT_FOUND)

        if convite.expira_em < timezone.now():
            return erro('Este convite expirou.', status_code=status.HTTP_400_BAD_REQUEST)

        return Response({'nome': convite.nome, 'email': convite.email, 'expira_em': convite.expira_em})

    @action(detail=False, methods=['post'], url_path=r'aceitar/(?P<token>[^/.]+)', permission_classes=[AllowAny])
    def aceitar_por_token(self, request, token=None):
        from django.db import connection
        from tenants.models import ConviteIndex, Tenant

        try:
            index = ConviteIndex.objects.get(token=token)
        except ConviteIndex.DoesNotExist:
            return erro('Convite não encontrado.', status_code=status.HTTP_404_NOT_FOUND)

        try:
            tenant = Tenant.objects.get(schema_name=index.schema_name)
        except Tenant.DoesNotExist:
            return erro('Convite não encontrado.', status_code=status.HTTP_404_NOT_FOUND)

        connection.set_tenant(tenant)

        try:
            convite = ConviteColaborador.objects.get(token=token)
        except ConviteColaborador.DoesNotExist:
            return erro('Convite não encontrado.', status_code=status.HTTP_404_NOT_FOUND)

        if convite.aceito:
            return erro('Convite já foi aceito.', status_code=status.HTTP_400_BAD_REQUEST)

        senha = request.data.get('senha', '').strip()
        if not senha:
            return erro('A senha é obrigatória.', status_code=status.HTTP_400_BAD_REQUEST)

        try:
            refresh = AceitarConviteService().aceitar(convite, senha)
            return responder_sessao(request, refresh, status.HTTP_201_CREATED)
        except ValueError as e:
            return erro(str(e), getattr(e, 'code', None), status.HTTP_400_BAD_REQUEST)
