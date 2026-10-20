"""Schemas OpenAPI versionados em backend/openapi/ (issue #6)."""
import os
import subprocess
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parent.parent


def test_schemas_versionados_estao_atualizados(tmp_path):
    """Regenera e compara com os arquivos do repositório.

    Falhou? Rode `python manage.py gerar_openapi` e versione backend/openapi/:
    é de lá que o front gera os clients Dart.
    """
    resultado = subprocess.run(
        [sys.executable, 'manage.py', 'gerar_openapi', '--pasta', str(tmp_path)],
        cwd=BACKEND,
        env={**os.environ, 'DJANGO_SETTINGS_MODULE': 'core.settings'},
        capture_output=True,
        text=True,
    )
    assert resultado.returncode == 0, resultado.stderr

    # Sem erro nem aviso: view sem tipo ficaria fora do schema, e enum sem nome
    # estável mudaria de tipo no client a cada regeração.
    saida = resultado.stdout + resultado.stderr
    assert 'Error' not in saida and 'Warning' not in saida, saida

    for produto in ('workmanage', 'servicemanage'):
        gerado = (tmp_path / f'{produto}.yaml').read_text()
        versionado = (BACKEND / 'openapi' / f'{produto}.yaml').read_text()
        assert gerado == versionado, f'openapi/{produto}.yaml desatualizado: rode manage.py gerar_openapi'
