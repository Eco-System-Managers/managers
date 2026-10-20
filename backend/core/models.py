import secrets
from datetime import timedelta

from django.contrib.auth.hashers import check_password, make_password
from django.db import models
from django.utils import timezone


class CodigoRecuperacaoBase(models.Model):
    """Código de recuperação de senha, comum aos dois produtos.

    Cada produto herda e declara só a FK para o dono da conta e o nome dela em
    `CAMPO_DONO` (o `User` no Work Manage, o `Consumidor` no Service Manage).
    """

    MAX_TENTATIVAS = 5
    VALIDADE = timedelta(minutes=15)
    CAMPO_DONO = None

    # Só o hash: com o banco vazado, o código ainda vivo não serve para nada.
    codigo_hash = models.CharField(max_length=128)
    criado_em = models.DateTimeField(auto_now_add=True)
    expira_em = models.DateTimeField()
    usado = models.BooleanField(default=False)
    tentativas = models.PositiveSmallIntegerField(default=0)

    class Meta:
        abstract = True
        ordering = ['-criado_em']

    def save(self, *args, **kwargs):
        if not self.pk:
            self.expira_em = timezone.now() + self.VALIDADE
        super().save(*args, **kwargs)

    @classmethod
    def emitir(cls, dono, codigo: str | None = None):
        """Cria um código novo e invalida os anteriores. Devolve o registro e o
        código em claro — a única vez em que ele existe fora do e-mail."""
        codigo = codigo or ''.join(secrets.choice('0123456789') for _ in range(8))
        cls.objects.filter(**{cls.CAMPO_DONO: dono, 'usado': False}).update(usado=True)
        return cls.objects.create(**{cls.CAMPO_DONO: dono, 'codigo_hash': make_password(codigo)}), codigo

    @property
    def dono(self):
        return getattr(self, self.CAMPO_DONO)

    def confere(self, codigo: str) -> bool:
        return check_password(codigo, self.codigo_hash)

    @property
    def expirado(self) -> bool:
        return timezone.now() > self.expira_em

    @property
    def bloqueado(self) -> bool:
        return self.tentativas >= self.MAX_TENTATIVAS

    def __str__(self):
        return f'{self.dono.email} — {self.criado_em:%d/%m/%Y %H:%M}'
