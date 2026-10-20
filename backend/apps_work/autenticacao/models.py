from django.contrib.auth.models import User
from django.db import models

from core.models import CodigoRecuperacaoBase

class UltimaAtividade(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='ultima_atividade')
    ultimo_acesso = models.DateTimeField()

    def __str__(self):
        return f'{self.user.email} — {self.ultimo_acesso}'


class CodigoRecuperacao(CodigoRecuperacaoBase):
    CAMPO_DONO = 'user'

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='codigos_recuperacao')

    class Meta(CodigoRecuperacaoBase.Meta):
        pass
