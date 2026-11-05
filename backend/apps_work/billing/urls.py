from django.urls import path

from .views import (
    CancelarAssinaturaView,
    ConfirmarAssinaturaView,
    IniciarAssinaturaView,
    MercadoPagoWebhookView,
    MinhaAssinaturaView,
    PagamentosListView,
    RetornoCheckoutView,
    RevenueCatWebhookView,
    SincronizarAssinaturaView,
)

urlpatterns = [
    path('billing/assinatura/', MinhaAssinaturaView.as_view(), name='minha-assinatura'),
    path('billing/assinatura/iniciar/', IniciarAssinaturaView.as_view(), name='iniciar-assinatura'),
    path('billing/assinatura/confirmar/', ConfirmarAssinaturaView.as_view(), name='confirmar-assinatura'),
    path('billing/assinatura/cancelar/', CancelarAssinaturaView.as_view(), name='cancelar-assinatura'),
    path('billing/assinatura/sincronizar/', SincronizarAssinaturaView.as_view(), name='sincronizar-assinatura'),
    path('billing/pagamentos/', PagamentosListView.as_view(), name='listar-pagamentos'),
    path('billing/retorno/', RetornoCheckoutView.as_view(), name='retorno-checkout'),
    path('billing/webhook/mercadopago/', MercadoPagoWebhookView.as_view(), name='webhook-mercadopago'),
    path('billing/webhook/revenuecat/', RevenueCatWebhookView.as_view(), name='webhook-revenuecat'),
]
