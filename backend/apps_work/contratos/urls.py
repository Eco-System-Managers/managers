from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import ContratoPublicoView, ContratoViewSet, ModeloContratoViewSet

router = DefaultRouter()
router.register('modelos', ModeloContratoViewSet, basename='modelo-contrato')
router.register('', ContratoViewSet, basename='contrato')

urlpatterns = [
    path('', include(router.urls)),
]

# Rota pública (sem autenticação) do contrato que o cliente abre pelo link do
# e-mail: <WORK>contratos/publico/<schema>/<token>/
publico_urlpatterns = [
    path(
        'publico/<str:schema_name>/<uuid:token>/',
        ContratoPublicoView.as_view(),
        name='contrato-publico',
    ),
]
