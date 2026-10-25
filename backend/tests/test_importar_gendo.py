"""Comando importar_gendo: a base de clientes do GENDO entra na ficha do tenant."""
from datetime import date
from decimal import Decimal
from io import StringIO

from unittest.mock import patch

import pytest
from django.core.management import CommandError, call_command
from django_tenants.utils import schema_context

from apps_work.clientes.models import Cliente
from apps_work.financeiro.models import TransacaoCredito

CABECALHO = (
    '"Código";"Nome";"DDI";"Telefone";"E-mail";"CPF";"Pendências";"Faturado";"Endereço";"Número";'
    '"Complemento";"Cidade";"Estado";"CEP";"Data de Nascimento";"Profissão";"Sexo";"Saldo";"Faturado";'
    '"Descritivo";"Visitas";"Ultima Visita"'
)
LINHAS = [
    # completa: endereço, CPF válido, crédito, descritivo
    '"10";"Ana Completa";"55";"11951068838";"Ana@Exemplo.com";"719.165.395-72";"12,50";"505,00";"Rua Um";"83";'
    '"casa";"Guarulhos";"SP";"07143-030";"30/11/1965";"";"Feminino";"12,50";"505,00";"Tem dermatite";"3";"2026-04-18"',
    # sem data (sentinela), devendo, mesmo CPF da Ana, telefone fixo
    '"11";"Bia Sentinela";"55";"1140028922";"";"71916539572";"-3,00";"0,00";"";"";"";"";"";"";"30/11/-0001";"";"---";"-3,00";"0,00";"";"0";""',
    # telefone internacional e nascimento absurdo
    '"12";"Carla Londres";"44";"7911123456";"";"";"0,00";"12,00";"";"";"";"";"";"";"16/03/2069";"";"";"0,00";"12,00";"";"1";"2017-02-08"',
    # telefone "fixo" de placeholder e uma linha sem nome, que é pulada
    '"13";"Dani Placeholder";"55";"1111111111";"";"";"0,00";"0,00";"";"";"";"";"";"";"--/--/----";"";"";"0,00";"0,00";"";"0";""',
    '"14";"";"55";"11999990000";"";"";"0,00";"0,00";"";"";"";"";"";"";"01/01/1990";"";"";"0,00";"0,00";"";"0";""',
    # código do país grudado no número
    '"15";"Edu Com Pais";"55";"5511934163627";"";"";"0,00";"0,00";"";"";"";"";"";"";"01/01/1990";"";"";"0,00";"0,00";"";"0";""',
]


@pytest.fixture
def csv_gendo(tmp_path):
    arquivo = tmp_path / 'gendo.csv'
    arquivo.write_text('\r\n'.join([CABECALHO, *LINHAS]) + '\r\n', encoding='latin-1')
    return str(arquivo)


def _rodar(arquivo, *extra):
    saida = StringIO()
    call_command('importar_gendo', arquivo, '--schema', 'test_empresa', *extra, stdout=saida)
    return saida.getvalue()


@pytest.mark.django_db
class TestImportarGendo:
    def test_importa_mapeando_a_ficha(self, tenant, csv_gendo):
        saida = _rodar(csv_gendo)

        with schema_context('test_empresa'):
            assert Cliente.objects.count() == 5
            ana = Cliente.objects.get(nome='Ana Completa')
            assert ana.telefone == '11951068838'
            assert ana.email == 'ana@exemplo.com'
            assert ana.cpf == '71916539572'
            assert ana.data_nascimento == date(1965, 11, 30)
            assert ana.cep == '07143030'
            assert ana.endereco == 'Rua Um (casa)'
            assert ana.numero_endereco == '83'
            assert 'Tem dermatite' in ana.observacao
            assert 'Cidade: Guarulhos / SP' in ana.observacao
            assert 'GENDO #10 · 3 visita(s) · última em 18/04/2026 · faturado R$ 505,00' in ana.observacao
            credito = TransacaoCredito.objects.get(cliente=ana)
            assert credito.valor == Decimal('12.50')
            assert credito.origem == 'manual'

            bia = Cliente.objects.get(nome='Bia Sentinela')
            assert bia.data_nascimento is None
            assert bia.telefone == '1140028922'
            # o CPF repetido fica no primeiro
            assert bia.cpf == ''
            assert 'Devia R$ 3,00 no GENDO' in bia.observacao
            assert not TransacaoCredito.objects.filter(cliente=bia).exists()

            carla = Cliente.objects.get(nome='Carla Londres')
            assert carla.telefone == ''
            assert 'Telefone no GENDO: +44 7911123456' in carla.observacao
            assert carla.data_nascimento is None

            # 10 dígitos com DDD válido é um fixo para o validador: entra como está
            dani = Cliente.objects.get(nome='Dani Placeholder')
            assert dani.telefone == '1111111111'

            assert Cliente.objects.get(nome='Edu Com Pais').telefone == '11934163627'

        assert 'Importados: 5' in saida
        assert 'pulados: 1' in saida
        assert 'créditos lançados: 1' in saida
        assert 'CPF 71916539572 já existe' in saida

    def test_rodar_de_novo_nao_duplica(self, tenant, csv_gendo):
        _rodar(csv_gendo)
        saida = _rodar(csv_gendo)

        with schema_context('test_empresa'):
            assert Cliente.objects.count() == 5
            assert TransacaoCredito.objects.count() == 1
        assert 'Importados: 0' in saida
        assert 'já importados: 5' in saida

    def test_dry_run_nao_grava(self, tenant, csv_gendo):
        saida = _rodar(csv_gendo, '--dry-run')

        with schema_context('test_empresa'):
            assert Cliente.objects.count() == 0
        assert 'Ensaio: nada foi gravado' in saida
        assert 'Importados: 5' in saida

    def test_sem_schema_lista_as_empresas_e_pergunta(self, tenant, csv_gendo):
        saida = StringIO()
        with patch('builtins.input', return_value='1'):
            call_command('importar_gendo', csv_gendo, stdout=saida)

        texto = saida.getvalue()
        assert 'Empresas cadastradas:' in texto
        assert '1) Empresa Teste  [test_empresa]' in texto
        assert 'Importando para Empresa Teste' in texto
        with schema_context('test_empresa'):
            assert Cliente.objects.count() == 5

    def test_resposta_vazia_ou_invalida_cancela(self, tenant, csv_gendo):
        for resposta in ('', '9', 'x'):
            with patch('builtins.input', return_value=resposta), pytest.raises(CommandError):
                call_command('importar_gendo', csv_gendo, stdout=StringIO())
        with schema_context('test_empresa'):
            assert Cliente.objects.count() == 0

    def test_recusa_tenant_e_arquivo_errados(self, tenant, csv_gendo, tmp_path):
        with pytest.raises(CommandError):
            call_command('importar_gendo', csv_gendo, '--schema', 'nao_existe')
        outro = tmp_path / 'outro.csv'
        outro.write_text('a;b\n1;2\n', encoding='latin-1')
        with pytest.raises(CommandError):
            call_command('importar_gendo', str(outro), '--schema', 'test_empresa')
