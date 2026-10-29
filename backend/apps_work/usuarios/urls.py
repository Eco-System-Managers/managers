from django.urls import path
from rest_framework.routers import DefaultRouter

from apps_work.autenticacao.views import ExcluirContaView
from .views import ColaboradorViewSet, ConviteColaboradorViewSet

router = DefaultRouter()
router.register(r'colaboradores', ColaboradorViewSet, basename='colaborador')
router.register(r'convites', ConviteColaboradorViewSet, basename='convite')

urlpatterns = [
    # A conta de quem está logado. Sob /me/, que escapa do bloqueio de
    # assinatura: quem não paga também pode sair.
    path('colaboradores/me/excluir/', ExcluirContaView.as_view(), name='excluir-conta'),
] + router.urls
