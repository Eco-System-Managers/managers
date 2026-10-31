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
        # utf-8 explícito: no Windows o padrão é cp1252, que não lê "Água"
        gerado = (tmp_path / f'{produto}.yaml').read_text(encoding='utf-8')
        versionado = (BACKEND / 'openapi' / f'{produto}.yaml').read_text(encoding='utf-8')
        assert gerado == versionado, f'openapi/{produto}.yaml desatualizado: rode manage.py gerar_openapi'


def test_toda_action_de_viewset_tem_extend_schema():
    """Sem @extend_schema, o drf-spectacular documenta a action com o
    serializer do viewset: o aceite de convite saía recebendo {nome, email} e
    devolvendo o convite, quando recebe {senha} e devolve a sessão — e o client
    Dart nasceria errado."""
    import ast

    faltando = []
    for arquivo in BACKEND.glob('apps_*/**/views.py'):
        for no in ast.walk(ast.parse(arquivo.read_text(encoding='utf-8'))):
            if not isinstance(no, ast.FunctionDef):
                continue
            nomes = [
                getattr(d.func, 'id', getattr(d.func, 'attr', None)) if isinstance(d, ast.Call) else getattr(d, 'id', None)
                for d in no.decorator_list
            ]
            if 'action' in nomes and 'extend_schema' not in nomes:
                faltando.append(f'{arquivo.relative_to(BACKEND)}:{no.lineno} {no.name}')
    assert not faltando, faltando
