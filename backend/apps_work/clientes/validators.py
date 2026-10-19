import re
from rest_framework import serializers

VALID_DDDS = {
    11, 12, 13, 14, 15, 16, 17, 18, 19,
    21, 22, 24,
    27, 28,
    31, 32, 33, 34, 35, 37, 38,
    41, 42, 43, 44, 45, 46,
    47, 48, 49,
    51, 53, 54, 55,
    61,
    62, 64,
    63,
    65, 66,
    67,
    68,
    69,
    71, 73, 74, 75, 77,
    79,
    81, 82, 83, 84, 85, 86, 87, 88, 89,
    91, 92, 93, 94, 95, 96, 97, 98, 99,
}


def validar_cpf(valor: str) -> str:
    digitos = re.sub(r'\D', '', valor)
    if len(digitos) != 11:
        raise serializers.ValidationError('CPF inválido. Informe 11 dígitos.')
    return digitos


def validar_telefone_br(valor: str) -> str:
    digitos = re.sub(r'\D', '', valor)

    if len(digitos) not in (10, 11):
        raise serializers.ValidationError(
            'Telefone inválido. Informe DDD + número (10 dígitos para fixo, 11 para celular).'
        )

    ddd = int(digitos[:2])
    if ddd not in VALID_DDDS:
        raise serializers.ValidationError(
            f'DDD {digitos[:2]} inválido.'
        )

    if len(digitos) == 11 and digitos[2] != '9':
        raise serializers.ValidationError(
            'Número de celular deve começar com 9 após o DDD.'
        )

    return digitos


_PLACA_ANTIGO = re.compile(r'^[A-Z]{3}\d{4}$')
_PLACA_MERCOSUL = re.compile(r'^[A-Z]{3}\d[A-Z]\d{2}$')


def validar_placa_br(valor: str) -> str:
    normalizada = re.sub(r'[-\s]', '', valor.strip().upper())
    if not (_PLACA_ANTIGO.match(normalizada) or _PLACA_MERCOSUL.match(normalizada)):
        raise serializers.ValidationError(
            'Placa inválida. Use o formato ABC-1234 (antigo) ou ABC1D23 (Mercosul).'
        )
    return normalizada
