from django.db import models
from core.tenant import TenantModel


class TipoNotificacao(models.TextChoices):
    CLIENTE_VINCULADO = 'cliente_vinculado', 'Cliente vinculado'
    CLIENTE_DESVINCULADO = 'cliente_desvinculado', 'Cliente desvinculado'


class Notificacao(TenantModel):
    tipo = models.CharField(max_length=30, choices=TipoNotificacao.choices)
    titulo = models.CharField(max_length=255)
    mensagem = models.CharField(max_length=500, blank=True)
    cliente = models.ForeignKey(
        'clientes.Cliente', on_delete=models.SET_NULL, null=True, blank=True, related_name='notificacoes'
    )
    lida = models.BooleanField(default=False)
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-criado_em']
        verbose_name = 'Notificação'
        verbose_name_plural = 'Notificações'

    def __str__(self):
        return self.titulo
