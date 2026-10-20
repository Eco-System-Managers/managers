"""Rotas do Service Manage (B2C), montadas sob core.rotas.SERVICEMANAGE."""
from django.conf import settings
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

from core.openapi import CONFIG_SERVICEMANAGE

urlpatterns = [
    path('', include('apps_serv.autenticacao.urls')),
    path('', include('apps_serv.consumidores.urls')),
    path('', include('apps_serv.vitrine.urls')),
]

# Schema OpenAPI do produto (core/openapi.py). Swagger UI só em DEBUG.
urlpatterns += [
    path('schema/', SpectacularAPIView.as_view(custom_settings=CONFIG_SERVICEMANAGE), name='schema-servicemanage'),
]
if settings.DEBUG:
    urlpatterns += [
        path('schema/docs/', SpectacularSwaggerView.as_view(url_name='schema-servicemanage'), name='docs-servicemanage'),
    ]
