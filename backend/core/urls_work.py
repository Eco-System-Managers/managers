"""Rotas do Work Manage (B2B), montadas sob core.rotas.WORK."""
from django.conf import settings
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

from core.openapi import CONFIG_WORK

from apps_work.contratos.urls import publico_urlpatterns

urlpatterns = [
    path('auth/', include('apps_work.autenticacao.urls')),
    path('', include('apps_work.clientes.urls')),
    path('', include('apps_work.servicos.urls')),
    path('', include('apps_work.agenda.urls')),
    path('', include('apps_work.usuarios.urls')),
    path('', include('apps_work.empresa.urls')),
    path('', include('apps_work.kanban.urls')),
    path('', include('apps_work.financeiro.urls')),
    path('', include('apps_work.dashboard.urls')),
    path('', include('apps_work.billing.urls')),
    path('', include('apps_work.notificacoes.urls')),
    # O público vem antes: o router de contratos tem um detalhe em '<pk>/'.
    path('contratos/', include(publico_urlpatterns)),
    path('contratos/', include('apps_work.contratos.urls')),
]

# Schema OpenAPI do produto (core/openapi.py). Swagger UI só em DEBUG.
urlpatterns += [
    path('schema/', SpectacularAPIView.as_view(custom_settings=CONFIG_WORK), name='schema-work'),
]
if settings.DEBUG:
    urlpatterns += [
        path('schema/docs/', SpectacularSwaggerView.as_view(url_name='schema-work'), name='docs-work'),
    ]
