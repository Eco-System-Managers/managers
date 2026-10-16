from django.urls import path
from rest_framework.routers import DefaultRouter
from .views import (
    AgendamentoViewSet,
    DiasComRegistroView,
    PendenciasCobrancaView,
    SlotsAgendaView,
)

router = DefaultRouter()
router.register(r'agendamentos', AgendamentoViewSet, basename='agendamento')

urlpatterns = router.urls + [
    path('agenda/dias-com-registro/', DiasComRegistroView.as_view(), name='dias-com-registro'),
    path('agenda/pendencias/', PendenciasCobrancaView.as_view(), name='pendencias-cobranca'),
    path('agenda/slots/', SlotsAgendaView.as_view(), name='agenda-slots'),
]
