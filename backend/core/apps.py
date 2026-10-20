from django.apps import AppConfig


class CoreConfig(AppConfig):
    name = 'core'

    def ready(self):
        # Registra as extensões de autenticação do drf-spectacular.
        from core import openapi  # noqa: F401
