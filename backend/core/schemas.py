import re

_SCHEMA_NAME_RE = re.compile(r'^[a-z0-9_]{1,63}$')


def schema_valido(schema_name: str) -> bool:
    """Formato do slug de negócio vindo da URL — entrada do usuário.

    Ele acaba virando `com_tenant`, então só passa o que um slug gerado pelo
    cadastro pode ser. 'public' nunca é alvo.
    """
    return bool(_SCHEMA_NAME_RE.match(schema_name or '')) and schema_name != 'public'
