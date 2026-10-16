from django.apps import AppConfig


class EmpresaConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps_work.empresa'

    def ready(self):
        import apps_work.empresa.signals  # noqa: F401
