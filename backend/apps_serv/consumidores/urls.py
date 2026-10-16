from django.urls import path

from .views import (
    CancelarAgendamentoView,
    FotoPerfilView,
    MeuPerfilView,
    MeusAgendamentosView,
    MeusVinculosView,
    ObjetoConsumidorDetailView,
    ObjetosConsumidorView,
)

urlpatterns = [
    path('me/', MeuPerfilView.as_view(), name='sm-me'),
    path('me/foto/', FotoPerfilView.as_view(), name='sm-me-foto'),
    path('agendamentos/', MeusAgendamentosView.as_view(), name='sm-agendamentos'),
    path('agendamentos/<int:agendamento_id>/cancelar/', CancelarAgendamentoView.as_view(), name='sm-cancelar'),
    path('vinculos/', MeusVinculosView.as_view(), name='sm-vinculos'),
    path('objetos/', ObjetosConsumidorView.as_view(), name='sm-objetos'),
    path('objetos/<int:objeto_id>/', ObjetoConsumidorDetailView.as_view(), name='sm-objeto-detalhe'),
]
