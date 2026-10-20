"""Prefixos versionados da API. Cada produto versiona sozinho.

Usados nas URLs, nos middlewares que agem por rota e no `path` dos cookies de
refresh — uma v2 muda aqui, não em strings espalhadas.
"""

# Work Manage (B2B): /api/v1/...  — inclusive /api/v1/auth/
WORK = '/api/v1/'
WORK_AUTH = f'{WORK}auth/'

# Service Manage (B2C): /api/sm/v1/...
SERVICEMANAGE = '/api/sm/v1/'
SERVICEMANAGE_AUTH = f'{SERVICEMANAGE}auth/'
