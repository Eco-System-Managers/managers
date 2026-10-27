from django.contrib import admin
from django.urls import include, path

from core import rotas

urlpatterns = [
    path('admin/', admin.site.urls),
    path(rotas.WORK.lstrip('/'), include('core.urls_work')),
    path(rotas.SERVICEMANAGE.lstrip('/'), include('core.urls_servicemanage')),
    # Páginas dos links de e-mail e do retorno do checkout (core/links.py).
    path('', include('apps_work.paginas.urls')),
]
