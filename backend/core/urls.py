from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import TokenRefreshView

from apps_work.contratos.urls import publico_urlpatterns

urlpatterns = [
    path('admin/', admin.site.urls),
    path('auth/', include('apps_work.autenticacao.urls')),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('api/', include('apps_work.clientes.urls')),
    path('api/', include('apps_work.servicos.urls')),
    path('api/', include('apps_work.agenda.urls')),
    path('api/', include('apps_work.usuarios.urls')),
    path('api/', include('apps_work.empresa.urls')),
    path('api/', include('apps_work.kanban.urls')),
    path('api/', include('apps_work.financeiro.urls')),
    path('api/', include('apps_work.dashboard.urls')),
    path('api/', include('apps_work.billing.urls')),
    path('api/', include('apps_work.notificacoes.urls')),
    path('api/contratos/', include('apps_work.contratos.urls')),
    path('api/sm/', include('apps_serv.autenticacao.urls')),
    path('api/sm/', include('apps_serv.consumidores.urls')),
    path('api/sm/', include('apps_serv.vitrine.urls')),
] + publico_urlpatterns
