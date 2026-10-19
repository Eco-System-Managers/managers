import re

from rest_framework import serializers

TIPO_CPF = 'cpf'
TIPO_CNPJ = 'cnpj'

_TAMANHO_POR_TIPO = {TIPO_CPF: 11, TIPO_CNPJ: 14}


def _digito(digitos: str, pesos: list[int]) -> int:
    soma = sum(int(d) * p for d, p in zip(digitos, pesos))
    resto = soma % 11
    return 0 if resto < 2 else 11 - resto


def _cpf_valido(digitos: str) -> bool:
    if len(set(digitos)) == 1:
        return False
    d1 = _digito(digitos[:9], list(range(10, 1, -1)))
    d2 = _digito(digitos[:10], list(range(11, 1, -1)))
    return digitos[9] == str(d1) and digitos[10] == str(d2)


def _cnpj_valido(digitos: str) -> bool:
    if len(set(digitos)) == 1:
        return False
    d1 = _digito(digitos[:12], [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2])
    d2 = _digito(digitos[:13], [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2])
    return digitos[12] == str(d1) and digitos[13] == str(d2)


def validar_documento(numero: str, tipo: str) -> str:
    """Valida CPF ou CNPJ pelo dígito verificador e devolve só os dígitos.
    A formatação (pontos, barra, traço) é responsabilidade da interface —
    o banco guarda o documento normalizado."""
    if tipo not in _TAMANHO_POR_TIPO:
        raise serializers.ValidationError({
            'detail': 'Tipo de documento inválido. Use "cpf" ou "cnpj".',
            'code': 'tipo_documento_invalido',
        })

    digitos = re.sub(r'\D', '', numero or '')
    rotulo = tipo.upper()

    if len(digitos) != _TAMANHO_POR_TIPO[tipo]:
        raise serializers.ValidationError({
            'detail': f'{rotulo} inválido. Informe {_TAMANHO_POR_TIPO[tipo]} dígitos.',
            'code': 'documento_invalido',
        })

    valido = _cpf_valido(digitos) if tipo == TIPO_CPF else _cnpj_valido(digitos)
    if not valido:
        raise serializers.ValidationError({
            'detail': f'{rotulo} inválido. Confira os números digitados.',
            'code': 'documento_invalido',
        })

    return digitos
