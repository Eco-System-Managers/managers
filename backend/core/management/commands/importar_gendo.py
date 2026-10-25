"""Importa a base de clientes exportada do GENDO (CSV) para um tenant.

O arquivo do GENDO vem em latin-1, separado por `;`, com 22 colunas. O que
tem lugar na ficha vai para o campo certo; o resto que ainda interessa
(cidade, visitas, faturamento, dívida) vai para a observação. Saldo positivo
vira crédito na comanda. O código do GENDO fica na observação e serve de
chave: rodar de novo não duplica.
"""
import csv
import re
from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal, InvalidOperation

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django_tenants.utils import schema_context
from rest_framework import serializers

from apps_work.clientes.validators import validar_cpf, validar_telefone_br

MARCADOR = 'GENDO #'
EMAIL = re.compile(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')


class _DryRun(Exception):
    """Desfaz a transação no fim do ensaio."""


@dataclass
class Linha:
    codigo: str
    nome: str
    telefone: str = ''
    email: str = ''
    cpf: str = ''
    data_nascimento: date | None = None
    cep: str = ''
    endereco: str = ''
    numero_endereco: str = ''
    observacao: str = ''
    credito: Decimal = Decimal('0')
    avisos: list = field(default_factory=list)


class Command(BaseCommand):
    help = 'Importa o CSV de clientes do GENDO para um tenant.'

    def add_arguments(self, parser):
        parser.add_argument('arquivo')
        parser.add_argument('--schema', help='schema da empresa que recebe os clientes; sem ele, o comando lista as empresas e pergunta')
        parser.add_argument('--encoding', default='latin-1')
        parser.add_argument('--dry-run', action='store_true', help='lê e valida tudo sem gravar')

    def handle(self, *args, arquivo, schema, encoding, dry_run, **options):
        from tenants.models import Tenant

        if schema is None:
            schema = self._escolher_empresa()
        elif not Tenant.objects.filter(schema_name=schema).exists():
            raise CommandError(f'Empresa {schema!r} não existe.')

        try:
            with open(arquivo, encoding=encoding, newline='') as f:
                linhas = list(csv.DictReader(f, delimiter=';'))
        except FileNotFoundError:
            raise CommandError(f'Arquivo {arquivo!r} não encontrado.')
        if not linhas or 'Código' not in linhas[0] or 'Nome' not in linhas[0]:
            raise CommandError('O arquivo não parece o export de clientes do GENDO (faltam Código e Nome).')

        resultado = {'importados': 0, 'ja_importados': 0, 'pulados': 0, 'creditos': 0, 'avisos': 0}
        try:
            with schema_context(schema), transaction.atomic():
                self._importar(linhas, resultado)
                if dry_run:
                    raise _DryRun
        except _DryRun:
            self.stdout.write(self.style.WARNING('Ensaio: nada foi gravado.'))

        self.stdout.write(self.style.SUCCESS(
            f"Importados: {resultado['importados']} | já importados: {resultado['ja_importados']} | "
            f"pulados: {resultado['pulados']} | créditos lançados: {resultado['creditos']} | "
            f"avisos: {resultado['avisos']}"
        ))

    def _escolher_empresa(self) -> str:
        """Lista as empresas do banco e deixa a pessoa escolher pelo número."""
        from tenants.models import Membro, Papel, Tenant

        empresas = list(Tenant.objects.exclude(schema_name='public').order_by('nome'))
        if not empresas:
            raise CommandError('Não há nenhuma empresa cadastrada.')

        self.stdout.write('Empresas cadastradas:')
        for i, tenant in enumerate(empresas, start=1):
            dono = Membro.objects.filter(tenant=tenant, papel=Papel.PROPRIETARIO).select_related('user').first()
            with schema_context(tenant.schema_name):
                from apps_work.clientes.models import Cliente
                clientes = Cliente.objects.count()
            email = dono.user.email if dono else 'sem dono'
            self.stdout.write(f'  {i:2d}) {tenant.nome}  [{tenant.schema_name}]  {email}  — {clientes} cliente(s)')

        resposta = input('Número da empresa que recebe os clientes (Enter cancela): ').strip()
        if not resposta:
            raise CommandError('Importação cancelada.')
        if not resposta.isdigit() or not 1 <= int(resposta) <= len(empresas):
            raise CommandError(f'Opção inválida: {resposta!r}.')
        escolhida = empresas[int(resposta) - 1]
        self.stdout.write(f'Importando para {escolhida.nome} [{escolhida.schema_name}].')
        return escolhida.schema_name

    def _importar(self, linhas, resultado):
        from apps_work.clientes.models import Cliente, OrigemCliente
        from apps_work.financeiro.models import OrigemTransacao, TipoTransacao, TransacaoCredito

        # O que já está no tenant, para não duplicar código nem CPF.
        codigos = set()
        for obs in Cliente.objects.filter(observacao__contains=MARCADOR).values_list('observacao', flat=True):
            codigos.update(re.findall(rf'{MARCADOR}(\d+)', obs))
        cpfs = set(Cliente.objects.exclude(cpf='').values_list('cpf', flat=True))

        for numero, bruto in enumerate(linhas, start=2):
            linha = self._converter(bruto, numero)
            if linha is None:
                resultado['pulados'] += 1
                continue
            if linha.codigo in codigos:
                resultado['ja_importados'] += 1
                continue
            if linha.cpf and linha.cpf in cpfs:
                linha.avisos.append(f'CPF {linha.cpf} já existe em outro cliente; ficou sem CPF')
                linha.cpf = ''

            cliente = Cliente.objects.create(
                nome=linha.nome,
                telefone=linha.telefone,
                email=linha.email,
                cpf=linha.cpf,
                data_nascimento=linha.data_nascimento,
                cep=linha.cep,
                endereco=linha.endereco,
                numero_endereco=linha.numero_endereco,
                observacao=linha.observacao,
                origem=OrigemCliente.MANUAL,
            )
            codigos.add(linha.codigo)
            if linha.cpf:
                cpfs.add(linha.cpf)
            if linha.credito > 0:
                TransacaoCredito.objects.create(
                    cliente=cliente,
                    tipo=TipoTransacao.CREDITO,
                    valor=linha.credito,
                    origem=OrigemTransacao.MANUAL,
                    descricao='Saldo importado do GENDO',
                )
                resultado['creditos'] += 1
            resultado['importados'] += 1
            for aviso in linha.avisos:
                resultado['avisos'] += 1
                self.stdout.write(f'linha {numero} ({linha.nome}): {aviso}')

    def _converter(self, bruto: dict, numero: int) -> Linha | None:
        def campo(nome):
            return (bruto.get(nome) or '').strip()

        nome = campo('Nome')
        codigo = campo('Código')
        if not nome or not codigo:
            self.stdout.write(f'linha {numero}: sem nome ou código, pulada')
            return None
        linha = Linha(codigo=codigo, nome=nome)
        extras = []

        # Telefone: a ficha exige DDD + número brasileiro. O que não passa
        # (internacional, incompleto, placeholder) fica anotado em vez de barrar.
        telefone = re.sub(r'\D', '', campo('Telefone'))
        ddi = campo('DDI') or '55'
        # alguns vieram com o código do país grudado no número
        if ddi == '55' and len(telefone) == 13 and telefone.startswith('55'):
            telefone = telefone[2:]
        if telefone and ddi != '55':
            linha.avisos.append(f'telefone internacional (+{ddi} {telefone}) foi para a observação')
            extras.append(f'Telefone no GENDO: +{ddi} {telefone}')
        elif telefone:
            try:
                linha.telefone = validar_telefone_br(telefone)
            except serializers.ValidationError:
                linha.avisos.append(f'telefone {telefone!r} inválido; foi para a observação')
                extras.append(f'Telefone no GENDO: {telefone}')
        else:
            linha.avisos.append('sem telefone')

        email = campo('E-mail').lower()
        if email and EMAIL.match(email):
            linha.email = email
        elif email:
            linha.avisos.append(f'e-mail {email!r} inválido, descartado')

        cpf = re.sub(r'\D', '', campo('CPF'))
        if cpf:
            try:
                linha.cpf = validar_cpf(cpf)
            except serializers.ValidationError:
                linha.avisos.append(f'CPF {cpf!r} inválido, descartado')

        linha.data_nascimento = self._data(campo('Data de Nascimento'), linha)

        complemento = campo('Complemento')
        linha.endereco = ' '.join(p for p in (campo('Endereço'), f'({complemento})' if complemento else '') if p)[:255]
        linha.numero_endereco = campo('Número')[:10]
        cep = re.sub(r'\D', '', campo('CEP'))
        if len(cep) == 8:
            linha.cep = cep
        elif cep:
            linha.avisos.append(f'CEP {cep!r} inválido, descartado')

        observacao = []
        if campo('Descritivo'):
            observacao.append(campo('Descritivo'))
        cidade = ' / '.join(p for p in (campo('Cidade'), campo('Estado')) if p)
        if cidade:
            observacao.append(f'Cidade: {cidade}')

        saldo = self._decimal(campo('Saldo') or campo('Pendências'))
        if saldo > 0:
            linha.credito = saldo
        elif saldo < 0:
            observacao.append(f'Devia R$ {-saldo:.2f} no GENDO'.replace('.', ','))

        historico = [f'{MARCADOR}{codigo}']
        visitas = campo('Visitas')
        if visitas:
            historico.append(f'{visitas} visita(s)')
        ultima = self._data_iso(campo('Ultima Visita'))
        if ultima:
            historico.append(f'última em {ultima:%d/%m/%Y}')
        faturado = self._decimal(campo('Faturado'))
        if faturado:
            historico.append(f'faturado R$ {faturado:.2f}'.replace('.', ','))
        observacao.append(' · '.join(historico))
        observacao.extend(extras)
        linha.observacao = '\n'.join(observacao)
        return linha

    def _data(self, valor: str, linha: Linha) -> date | None:
        # "30/11/-0001" e "--/--/----" são o jeito do GENDO dizer "sem data"
        if not valor or '-0001' in valor or valor.startswith('--'):
            return None
        try:
            data = datetime.strptime(valor, '%d/%m/%Y').date()
        except ValueError:
            linha.avisos.append(f'nascimento {valor!r} inválido, descartado')
            return None
        if data.year < 1900 or data > date.today():
            linha.avisos.append(f'nascimento {valor!r} fora da realidade, descartado')
            return None
        return data

    @staticmethod
    def _data_iso(valor: str) -> date | None:
        try:
            return date.fromisoformat(valor) if valor else None
        except ValueError:
            return None

    @staticmethod
    def _decimal(valor: str) -> Decimal:
        # "1.505,00" -> 1505.00
        try:
            return Decimal(valor.replace('.', '').replace(',', '.')) if valor else Decimal('0')
        except InvalidOperation:
            return Decimal('0')
