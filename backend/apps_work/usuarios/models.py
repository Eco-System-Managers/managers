import uuid

from django.db import models
from django.contrib.auth.models import User


class Colaborador(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='colaborador')
    funcao = models.CharField(max_length=100, blank=True)
    ativo = models.BooleanField(default=True)
    criado_em = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.user.get_full_name() or self.user.email


class ConviteColaborador(models.Model):
    nome = models.CharField(max_length=150, blank=True, default='')
    email = models.EmailField()
    token = models.UUIDField(default=uuid.uuid4, unique=True)
    aceito = models.BooleanField(default=False)
    criado_em = models.DateTimeField(auto_now_add=True)
    expira_em = models.DateTimeField()

    def __str__(self):
        return f'Convite → {self.nome} <{self.email}>'
