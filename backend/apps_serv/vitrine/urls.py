from django.urls import path

from .views import (
    CidadesView,
    CriarAgendamentoView,
    DisponibilidadeView,
    EquipeNegocioView,
    HorariosNegocioView,
    NegocioPublicoDetailView,
    NegociosPublicosView,
    NichosView,
    ServicosNegocioView,
    VincularNegocioView,
)

urlpatterns = [
    path('negocios/', NegociosPublicosView.as_view(), name='sm-negocios'),
    path('negocios/cidades/', CidadesView.as_view(), name='sm-cidades'),
    path('negocios/nichos/', NichosView.as_view(), name='sm-nichos'),
    path('negocios/<str:schema_name>/', NegocioPublicoDetailView.as_view(), name='sm-negocio-detalhe'),
    path('negocios/<str:schema_name>/servicos/', ServicosNegocioView.as_view(), name='sm-servicos'),
    path('negocios/<str:schema_name>/equipe/', EquipeNegocioView.as_view(), name='sm-equipe'),
    path('negocios/<str:schema_name>/horarios/', HorariosNegocioView.as_view(), name='sm-horarios'),
    path('negocios/<str:schema_name>/disponibilidade/', DisponibilidadeView.as_view(), name='sm-disponibilidade'),
    path('negocios/<str:schema_name>/agendamentos/', CriarAgendamentoView.as_view(), name='sm-criar-agendamento'),
    path('negocios/<str:schema_name>/vincular/', VincularNegocioView.as_view(), name='sm-vincular'),
]
