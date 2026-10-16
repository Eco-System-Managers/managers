from django.urls import path

from .views import (
    CadastroConsumidorView,
    LoginConsumidorView,
    LogoutConsumidorView,
    NovaSenhaConsumidorView,
    RecuperarSenhaConsumidorView,
    RefreshConsumidorView,
    VerificarCodigoConsumidorView,
)

urlpatterns = [
    path('auth/cadastro/', CadastroConsumidorView.as_view(), name='sm-cadastro'),
    path('auth/login/', LoginConsumidorView.as_view(), name='sm-login'),
    path('auth/refresh/', RefreshConsumidorView.as_view(), name='sm-refresh'),
    path('auth/logout/', LogoutConsumidorView.as_view(), name='sm-logout'),
    path('auth/recuperar-senha/', RecuperarSenhaConsumidorView.as_view(), name='sm-recuperar-senha'),
    path('auth/verificar-codigo/', VerificarCodigoConsumidorView.as_view(), name='sm-verificar-codigo'),
    path('auth/nova-senha/', NovaSenhaConsumidorView.as_view(), name='sm-nova-senha'),
]
