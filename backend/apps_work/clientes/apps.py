from django.apps import AppConfig


class ClientesConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps_work.clientes'

    def ready(self):
        import apps_work.clientes.signals  # noqa: F401

