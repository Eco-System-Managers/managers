import uuid

from django.db import models


class ModeloContrato(models.Model):
    titulo = models.CharField(max_length=255)
    corpo = models.TextField(
        help_text=(
            'Variáveis disponíveis: {{cliente_nome}}, {{cliente_email}}, '
            '{{cliente_cpf}}, {{data}}, {{negocio_nome}}'
        )
    )
    ativo = models.BooleanField(default=True)
    criado_em = models.DateTimeField(auto_now_add=True)
    atualizado_em = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-criado_em']
        verbose_name = 'Modelo de Contrato'
        verbose_name_plural = 'Modelos de Contrato'

    def __str__(self):
        return self.titulo


class StatusContrato(models.TextChoices):
    PENDENTE = 'pendente', 'Pendente'
    ENVIADO = 'enviado', 'Enviado'
    ASSINADO = 'assinado', 'Assinado'
    RECUSADO = 'recusado', 'Recusado'


class Contrato(models.Model):
    modelo = models.ForeignKey(
        ModeloContrato,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='contratos',
    )
    cliente = models.ForeignKey(
        'clientes.Cliente',
        on_delete=models.CASCADE,
        related_name='contratos',
    )
    titulo = models.CharField(max_length=255)
    corpo = models.TextField()
    status = models.CharField(max_length=20, choices=StatusContrato.choices, default=StatusContrato.PENDENTE)
    token = models.UUIDField(unique=True, default=uuid.uuid4, editable=False)

    # Registro de assinatura
    nome_assinante = models.CharField(max_length=255, blank=True)
    ip_assinante = models.GenericIPAddressField(null=True, blank=True)
    assinado_em = models.DateTimeField(null=True, blank=True)

    criado_em = models.DateTimeField(auto_now_add=True)
    atualizado_em = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-criado_em']
        verbose_name = 'Contrato'
        verbose_name_plural = 'Contratos'

    def __str__(self):
        return f'{self.titulo} — {self.cliente}'
