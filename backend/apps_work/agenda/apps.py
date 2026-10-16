from django.apps import AppConfig


class AgendaConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps_work.agenda'

    def ready(self):
        import apps_work.agenda.signals  # noqa: F401

