from django.urls import path

from .views import ContratoView, ConviteView, RetornoPagamentoView

# Os caminhos são os de core/links.py, sem barra no fim: é como saem nos
# e-mails e no redirect do checkout.
urlpatterns = [
    path('convite/<str:token>', ConviteView.as_view(), name='pagina-convite'),
    path('contrato/<str:schema_name>/<uuid:token>', ContratoView.as_view(), name='pagina-contrato'),
    path('app/pagamentos', RetornoPagamentoView.as_view(), name='pagina-pagamentos'),
]
