from decimal import Decimal

from django.db import models


class Servico(models.Model):
    TAXA_CANCELAMENTO_TIPO_CHOICES = [
        ('valor', 'Valor fixo (R$)'),
        ('percentual', 'Percentual (%)'),
    ]

    nome = models.CharField(max_length=255)
    descricao = models.TextField(blank=True)
    duracao = models.PositiveIntegerField(help_text='Duração em minutos')
    preco = models.DecimalField(max_digits=8, decimal_places=2)
    taxa_cancelamento_tipo = models.CharField(max_length=10, choices=TAXA_CANCELAMENTO_TIPO_CHOICES, blank=True)
    taxa_cancelamento_valor = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    ativo = models.BooleanField(default=True)
    colaboradores = models.ManyToManyField(
        'usuarios.Colaborador',
        blank=True,
        related_name='servicos',
    )

    def __str__(self):
        return self.nome

    def calcular_taxa_cancelamento(self) -> Decimal:
        if self.taxa_cancelamento_tipo == 'percentual':
            return (self.preco * self.taxa_cancelamento_valor / Decimal('100')).quantize(Decimal('0.01'))
        if self.taxa_cancelamento_tipo == 'valor':
            return self.taxa_cancelamento_valor
        return Decimal('0')
