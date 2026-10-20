from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand
from drf_spectacular.generators import SchemaGenerator
from drf_spectacular.renderers import OpenApiYamlRenderer
from drf_spectacular.settings import patched_settings

from core.openapi import CONFIG_SERVICEMANAGE, CONFIG_WORK

PRODUTOS = {
    'workmanage': CONFIG_WORK,
    'servicemanage': CONFIG_SERVICEMANAGE,
}


class Command(BaseCommand):
    help = 'Gera backend/openapi/<produto>.yaml, de onde o front gera os clients Dart.'

    def add_arguments(self, parser):
        parser.add_argument('--pasta', default=str(Path(settings.BASE_DIR) / 'openapi'))

    def handle(self, *args, pasta, **options):
        destino = Path(pasta)
        destino.mkdir(parents=True, exist_ok=True)
        for produto, config in PRODUTOS.items():
            with patched_settings(config):
                schema = SchemaGenerator().get_schema(request=None, public=True)
            arquivo = destino / f'{produto}.yaml'
            arquivo.write_bytes(OpenApiYamlRenderer().render(schema, renderer_context={}))
            self.stdout.write(f'{arquivo} ({len(schema["paths"])} rotas)')
