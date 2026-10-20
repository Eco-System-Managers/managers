import secrets

from django.contrib.auth.hashers import check_password, make_password
from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta


class UltimaAtividade(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='ultima_atividade')
    ultimo_acesso = models.DateTimeField()

    def __str__(self):
        return f'{self.user.email} — {self.ultimo_acesso}'


class CodigoRecuperacao(models.Model):
    MAX_TENTATIVAS = 5

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='codigos_recuperacao')
    # Só o hash: com o banco vazado, o código ainda vivo não serve para nada.
    codigo_hash = models.CharField(max_length=128)
    criado_em = models.DateTimeField(auto_now_add=True)
    expira_em = models.DateTimeField()
    usado = models.BooleanField(default=False)
    tentativas = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ['-criado_em']

    def save(self, *args, **kwargs):
        if not self.pk:
            self.expira_em = timezone.now() + timedelta(minutes=15)
        super().save(*args, **kwargs)

    @classmethod
    def emitir(cls, user, codigo: str | None = None) -> tuple['CodigoRecuperacao', str]:
        """Cria um código novo e invalida os anteriores. Devolve o registro e o
        código em claro — a única vez em que ele existe fora do e-mail."""
        codigo = codigo or ''.join(secrets.choice('0123456789') for _ in range(8))
        cls.objects.filter(user=user, usado=False).update(usado=True)
        return cls.objects.create(user=user, codigo_hash=make_password(codigo)), codigo

    def confere(self, codigo: str) -> bool:
        return check_password(codigo, self.codigo_hash)

    @property
    def expirado(self):
        return timezone.now() > self.expira_em

    @property
    def bloqueado(self):
        return self.tentativas >= self.MAX_TENTATIVAS

    def __str__(self):
        return f'{self.user.email} — {self.criado_em:%d/%m/%Y %H:%M}'
