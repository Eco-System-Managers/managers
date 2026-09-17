from django.db import models
from django.contrib.auth.models import User


class MembroEmpresa(models.Model):
    ROLE_CHOICES = [
        ('proprietario', 'Proprietário'),
        ('colaborador', 'Colaborador'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='membro_empresa')
    funcao = models.CharField(max_length=100, blank=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='colaborador')
    ativo = models.BooleanField(default=True)
    criado_em = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.user.get_full_name()} — {self.get_role_display()}'
