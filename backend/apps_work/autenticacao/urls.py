from django.urls import path
from .views import (
    CadastroView, CookieTokenRefreshView, LoginView, LogoutView,
    NovaSenhaView, RecuperarSenhaView, VerificarCodigoView,
)

urlpatterns = [
    path('cadastro/', CadastroView.as_view(), name='auth-cadastro'),
    path('login/', LoginView.as_view(), name='auth-login'),
    path('token-refresh/', CookieTokenRefreshView.as_view(), name='auth-token-refresh'),
    path('logout/', LogoutView.as_view(), name='auth-logout'),
    path('recuperar-senha/', RecuperarSenhaView.as_view(), name='auth-recuperar-senha'),
    path('verificar-codigo/', VerificarCodigoView.as_view(), name='auth-verificar-codigo'),
    path('nova-senha/', NovaSenhaView.as_view(), name='auth-nova-senha'),
]