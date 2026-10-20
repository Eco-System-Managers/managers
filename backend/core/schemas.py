import re

_SCHEMA_NAME_RE = re.compile(r'^[a-z0-9_]{1,63}$')


def schema_valido(schema_name: str) -> bool:
    """Formato de schema de tenant vindo da URL — entrada do usuário.

    Ele acaba virando troca de schema (`schema_context`), então só passa o que
    um schema gerado pelo cadastro pode ser. O schema público nunca é alvo.
    """
    return bool(_SCHEMA_NAME_RE.match(schema_name or '')) and schema_name != 'public'
