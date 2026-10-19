from django.db import models


CATEGORIA_DESPESA_CHOICES = [
    ('aluguel', 'Aluguel'),
    ('agua_luz', 'Água / Luz'),
    ('internet_telefone', 'Internet / Telefone'),
    ('produtos', 'Produtos e insumos'),
    ('equipamentos', 'Equipamentos'),
    ('salarios', 'Salários / Comissões'),
    ('impostos', 'Impostos e taxas'),
    ('marketing', 'Marketing'),
    ('manutencao', 'Manutenção'),
    ('outros', 'Outros'),
]


class TransacaoCredito(models.Model):
    TIPO_CHOICES = [
        ('credito', 'Crédito'),
        ('debito', 'Débito'),
    ]
    ORIGEM_CHOICES = [
        ('troco', 'Troco de atendimento'),
        ('manual', 'Lançamento manual'),
        ('b2c', 'Crédito do app'),
        ('desconto_aplicado', 'Desconto de saldo'),
        ('taxa_cancelamento', 'Taxa de cancelamento'),
    ]

    cliente = models.ForeignKey(
        'clientes.Cliente', on_delete=models.CASCADE, related_name='transacoes_credito'
    )
    tipo = models.CharField(max_length=10, choices=TIPO_CHOICES)
    valor = models.DecimalField(max_digits=10, decimal_places=2)
    origem = models.CharField(max_length=20, choices=ORIGEM_CHOICES, default='manual')
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
    categoria = models.CharField(max_length=30, choices=CATEGORIA_DESPESA_CHOICES, default='outros')
    data = models.DateField()
    observacao = models.TextField(blank=True)
    criado_em = models.DateTimeField(auto_now_add=True)
    atualizado_em = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-data', '-criado_em']

    def __str__(self):
        return f'{self.descricao} — R${self.valor} ({self.data})'
