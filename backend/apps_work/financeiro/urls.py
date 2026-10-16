from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import CaixaView, DespesaViewSet, SaldoClienteView

router = DefaultRouter()
router.register(r'financeiro/despesas', DespesaViewSet, basename='despesa')

urlpatterns = [
    path('financeiro/caixa/', CaixaView.as_view(), name='financeiro-caixa'),
    path('financeiro/clientes/<int:cliente_id>/saldo/', SaldoClienteView.as_view(), name='saldo-cliente'),
    *router.urls,
]
