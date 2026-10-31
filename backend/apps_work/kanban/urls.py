from django.urls import path
from rest_framework.routers import DefaultRouter
from .views import AtendimentoKanbanViewSet, CapacidadeView, EtapaKanbanViewSet, SlotsView

router = DefaultRouter()
router.register('kanban/etapas', EtapaKanbanViewSet, basename='etapa-kanban')
router.register('kanban/atendimentos', AtendimentoKanbanViewSet, basename='atendimento-kanban')

urlpatterns = router.urls + [
    path('kanban/slots/', SlotsView.as_view(), name='kanban-slots'),
    path('kanban/capacidade/', CapacidadeView.as_view(), name='kanban-capacidade'),
]
