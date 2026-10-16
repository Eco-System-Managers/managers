from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import ContratoPublicoView, ContratoViewSet, ModeloContratoViewSet

router = DefaultRouter()
router.register('modelos', ModeloContratoViewSet, basename='modelo-contrato')
router.register('', ContratoViewSet, basename='contrato')

urlpatterns = [
    path('', include(router.urls)),
]

# Rotas públicas (sem autenticação) — fora do router pois não passam pelo tenant middleware
publico_urlpatterns = [
    path(
        'contratos/<str:schema_name>/<uuid:token>/',
        ContratoPublicoView.as_view(),
        name='contrato-publico',
    ),
]
