from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta


class LastActivity(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='last_activity')
    ultimo_acesso = models.DateTimeField()

    def __str__(self):
        return f'{self.user.email} — {self.ultimo_acesso}'


class CodigoRecuperacao(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='codigos_recuperacao')
    codigo = models.CharField(max_length=8)
    criado_em = models.DateTimeField(auto_now_add=True)
    expira_em = models.DateTimeField()
    usado = models.BooleanField(default=False)

    class Meta:
        ordering = ['-criado_em']

    def save(self, *args, **kwargs):
        if not self.pk:
            self.expira_em = timezone.now() + timedelta(minutes=15)
        super().save(*args, **kwargs)

    @property
    def expirado(self):
        return timezone.now() > self.expira_em

    def __str__(self):
        return f'{self.user.email} — {self.codigo}'
