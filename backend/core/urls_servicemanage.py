"""Rotas do Service Manage (B2C), montadas sob core.rotas.SERVICEMANAGE."""
from django.urls import include, path

urlpatterns = [
    path('', include('apps_serv.autenticacao.urls')),
    path('', include('apps_serv.consumidores.urls')),
    path('', include('apps_serv.vitrine.urls')),
]
