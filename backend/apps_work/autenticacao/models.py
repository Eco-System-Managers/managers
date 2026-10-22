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


class CadastroPendente(models.Model):
    """Cadastro esperando o código enviado por e-mail.

    A empresa só nasce na confirmação: criar o tenant roda as migrations de um
    schema inteiro, e não pode acontecer para um e-mail que ninguém confirmou.
    """

    email = models.EmailField(unique=True)
    nome_empresa = models.CharField(max_length=255)
    nome = models.CharField(max_length=150)
    # Só o hash, como no User: a senha em claro não fica nem enquanto espera.
    senha_hash = models.CharField(max_length=128)
    criado_em = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.email} — {self.nome_empresa}'


class CodigoCadastro(CodigoRecuperacaoBase):
    """Código de confirmação do cadastro. Mesma mecânica do de recuperação:
    hash, 15 minutos de validade e 5 tentativas."""

    CAMPO_DONO = 'cadastro'

    cadastro = models.ForeignKey(CadastroPendente, on_delete=models.CASCADE, related_name='codigos')

    class Meta(CodigoRecuperacaoBase.Meta):
        pass
