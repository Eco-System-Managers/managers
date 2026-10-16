import pytest
from rest_framework import serializers
from apps_work.clientes.validators import validar_telefone_br, validar_cpf


class TestValidarTelefoneBR:
    def test_celular_valido_retorna_digitos(self):
        assert validar_telefone_br('11999990000') == '11999990000'

    def test_fixo_valido_retorna_digitos(self):
        assert validar_telefone_br('1133334444') == '1133334444'

    def test_numero_formatado_e_normalizado(self):
        assert validar_telefone_br('(11) 99999-0000') == '11999990000'

    def test_menos_de_10_digitos_lanca_excecao(self):
        with pytest.raises(serializers.ValidationError):
            validar_telefone_br('119999000')

    def test_mais_de_11_digitos_lanca_excecao(self):
        with pytest.raises(serializers.ValidationError):
            validar_telefone_br('119999900001')

    def test_ddd_invalido_lanca_excecao(self):
        with pytest.raises(serializers.ValidationError, match='DDD'):
            validar_telefone_br('01999990000')

    def test_celular_sem_9_apos_ddd_lanca_excecao(self):
        with pytest.raises(serializers.ValidationError):
            validar_telefone_br('11899990000')

    def test_ddd_valido_nordeste_aceito(self):
        assert validar_telefone_br('81999990000') == '81999990000'

    def test_ddd_valido_sul_aceito(self):
        assert validar_telefone_br('47999990000') == '47999990000'


class TestValidarCPF:
    def test_cpf_com_11_digitos_valido(self):
        assert validar_cpf('12345678901') == '12345678901'

    def test_cpf_formatado_e_normalizado(self):
        assert validar_cpf('123.456.789-01') == '12345678901'

    def test_cpf_com_menos_de_11_digitos_lanca_excecao(self):
        with pytest.raises(serializers.ValidationError):
            validar_cpf('1234567890')

    def test_cpf_com_mais_de_11_digitos_lanca_excecao(self):
        with pytest.raises(serializers.ValidationError):
            validar_cpf('123456789012')

    def test_cpf_vazio_lanca_excecao(self):
        with pytest.raises(serializers.ValidationError):
            validar_cpf('')

    def test_cpf_apenas_letras_lanca_excecao(self):
        with pytest.raises(serializers.ValidationError):
            validar_cpf('abcdefghijk')
