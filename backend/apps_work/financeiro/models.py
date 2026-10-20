from django.db import models


class CategoriaDespesa(models.TextChoices):
    ALUGUEL = 'aluguel', 'Aluguel'
    AGUA_LUZ = 'agua_luz', 'Água / Luz'
    INTERNET_TELEFONE = 'internet_telefone', 'Internet / Telefone'
    PRODUTOS = 'produtos', 'Produtos e insumos'
    EQUIPAMENTOS = 'equipamentos', 'Equipamentos'
    SALARIOS = 'salarios', 'Salários / Comissões'
    IMPOSTOS = 'impostos', 'Impostos e taxas'
    MARKETING = 'marketing', 'Marketing'
    MANUTENCAO = 'manutencao', 'Manutenção'
    OUTROS = 'outros', 'Outros'


class TipoTransacao(models.TextChoices):
    CREDITO = 'credito', 'Crédito'
    DEBITO = 'debito', 'Débito'


class OrigemTransacao(models.TextChoices):
    TROCO = 'troco', 'Troco de atendimento'
    MANUAL = 'manual', 'Lançamento manual'
    B2C = 'b2c', 'Crédito do app'
    DESCONTO_APLICADO = 'desconto_aplicado', 'Desconto de saldo'
    TAXA_CANCELAMENTO = 'taxa_cancelamento', 'Taxa de cancelamento'


class TransacaoCredito(models.Model):
    cliente = models.ForeignKey(
        'clientes.Cliente', on_delete=models.CASCADE, related_name='transacoes_credito'
    )
    tipo = models.CharField(max_length=10, choices=TipoTransacao.choices)
    valor = models.DecimalField(max_digits=10, decimal_places=2)
    origem = models.CharField(max_length=20, choices=OrigemTransacao.choices, default=OrigemTransacao.MANUAL)
    descricao = models.CharField(max_length=255, blank=True)
    atendimento_kanban = models.ForeignKey(
        'kanban.AtendimentoKanban',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='transacoes_credito',
    )
    agendamento = models.ForeignKey(
        'agenda.Agendamento',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='transacoes_credito',
    )
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-criado_em']

    def __str__(self):
        return f'{self.get_tipo_display()} R${self.valor} — {self.cliente}'


class Despesa(models.Model):
    descricao = models.CharField(max_length=255)
    valor = models.DecimalField(max_digits=10, decimal_places=2)
    categoria = models.CharField(max_length=30, choices=CategoriaDespesa.choices, default=CategoriaDespesa.OUTROS)
    data = models.DateField()
    observacao = models.TextField(blank=True)
    criado_em = models.DateTimeField(auto_now_add=True)
    atualizado_em = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-data', '-criado_em']

    def __str__(self):
        return f'{self.descricao} — R${self.valor} ({self.data})'
