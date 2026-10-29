from decimal import Decimal

from django.db import models

from apps_work.empresa.models import Nicho


class TipoTaxaCancelamento(models.TextChoices):
    VALOR = 'valor', 'Valor fixo (R$)'
    PERCENTUAL = 'percentual', 'Percentual (%)'


class Servico(models.Model):
    nome = models.CharField(max_length=255)
    # A pasta do serviço: um dos nichos do negócio. Gravado sempre, mesmo com
    # um nicho só — a interface é que esconde a pasta nesse caso.
    nicho = models.CharField(max_length=50, choices=Nicho.choices)
    descricao = models.TextField(blank=True)
    duracao = models.PositiveIntegerField(help_text='Duração em minutos')
    preco = models.DecimalField(max_digits=8, decimal_places=2)
    taxa_cancelamento_tipo = models.CharField(max_length=10, choices=TipoTaxaCancelamento.choices, blank=True)
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
        if self.taxa_cancelamento_tipo == TipoTaxaCancelamento.PERCENTUAL:
            return (self.preco * self.taxa_cancelamento_valor / Decimal('100')).quantize(Decimal('0.01'))
        if self.taxa_cancelamento_tipo == TipoTaxaCancelamento.VALOR:
            return self.taxa_cancelamento_valor
        return Decimal('0')
