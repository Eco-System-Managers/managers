from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    EmpresaConfigView,
    GeocodificarView,
    HorarioFuncionamentoViewSet,
    RuaNoPontoView,
    UploadLogoView,
)

router = DefaultRouter()
router.register(r'empresa/horarios', HorarioFuncionamentoViewSet, basename='horario')

urlpatterns = [
    path('empresa/config/', EmpresaConfigView.as_view(), name='empresa-config'),
    path('empresa/config/logo/', UploadLogoView.as_view(), name='empresa-logo'),
    path('empresa/geocodificar/', GeocodificarView.as_view(), name='empresa-geocodificar'),
    path('empresa/rua-no-ponto/', RuaNoPontoView.as_view(), name='empresa-rua-no-ponto'),
    path('', include(router.urls)),
]
