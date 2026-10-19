from datetime import date
from django.db import models


class Plano(models.Model):
    TIPO_CHOICES = [
        ('pro', 'Pro'),
        ('business', 'Business'),
        ('enterprise', 'Enterprise'),
    ]

    nome = models.CharField(max_length=50, choices=TIPO_CHOICES, unique=True)
    preco_mensal = models.DecimalField(max_digits=8, decimal_places=2)
    limite_colaboradores = models.IntegerField(null=True, blank=True)
    ativo = models.BooleanField(default=True)
    mercadopago_plan_id = models.CharField(max_length=100, blank=True)
    mercadopago_init_point = models.URLField(max_length=500, blank=True)

    def __str__(self):
        return self.get_nome_display()


class Assinatura(models.Model):
    STATUS_CHOICES = [
        ('ativa', 'Ativa'),
        ('cancelada', 'Cancelada'),
        ('inadimplente', 'Inadimplente'),
        ('trial', 'Trial'),
    ]

    tenant = models.OneToOneField('tenants.Tenant', on_delete=models.CASCADE, related_name='assinatura')
    plano = models.ForeignKey(Plano, on_delete=models.PROTECT)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='trial')
    inicio = models.DateField()
    proximo_vencimento = models.DateField()
    trial_fim = models.DateField(null=True, blank=True)
    mercadopago_preapproval_id = models.CharField(max_length=100, blank=True, null=True, unique=True)

    @property
    def bloqueada(self) -> bool:
        if self.status == 'inadimplente':
            return True
        if self.status == 'trial':
            return self.trial_fim is not None and self.trial_fim < date.today()
        if self.status == 'cancelada':
            # Cancelar não bloqueia na hora — a pessoa mantém acesso até o
            # fim do período já pago (mesma data usada pra cobrar de novo).
            return self.proximo_vencimento is None or self.proximo_vencimento < date.today()
        return False

    def _invalidar_cache(self) -> None:
        """Derruba o estado memorizado pelo AssinaturaBloqueadaMiddleware.

        Fica no model, e nao nos services, de proposito: a assinatura e salva em
        varios pontos do fluxo de cobranca (confirmacao, cancelamento, webhook,
        retorno do checkout). Invalidar em cada um deles deixaria a correcao
        dependendo de ninguem esquecer — e o esquecimento aparece como cliente
        que pagou e continua vendo a tela de bloqueio.
        """
        from core.cache import invalidar_assinatura

        # tenant_id sem o objeto carregado custaria uma consulta so para achar o
        # schema; salvar assinatura e raro, entao vale o preco.
        invalidar_assinatura(self.tenant.schema_name)

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        self._invalidar_cache()

    def delete(self, *args, **kwargs):
        # Guardado antes: depois do delete o acesso ao tenant ainda funciona,
        # mas nao ha razao para depender disso.
        schema_name = self.tenant.schema_name
        resultado = super().delete(*args, **kwargs)

        from core.cache import invalidar_assinatura
        invalidar_assinatura(schema_name)
        return resultado

    def __str__(self):
        return f'{self.tenant} — {self.plano}'


class Pagamento(models.Model):
    STATUS_CHOICES = [
        ('pago', 'Pago'),
        ('pendente', 'Pendente'),
        ('falhou', 'Falhou'),
    ]

    assinatura = models.ForeignKey(Assinatura, on_delete=models.CASCADE, related_name='pagamentos')
    valor = models.DecimalField(max_digits=8, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pendente')
    data = models.DateField()
    referencia_externa = models.CharField(max_length=255, blank=True)
    mercadopago_payment_id = models.CharField(max_length=100, blank=True, null=True, unique=True)

    def __str__(self):
        return f'{self.assinatura.tenant} — {self.data} — {self.status}'
