from django.apps import AppConfig


class VitrineConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps_serv.vitrine'
    verbose_name = 'Vitrine'

    def ready(self):
        import apps_serv.vitrine.handlers  # noqa: F401
