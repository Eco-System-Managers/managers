import uuid
from decimal import Decimal

from django.db import models
from django.contrib.auth.models import User


class VinculoColaborador(models.TextChoices):
    # parceiro: agenda e faturamento próprios (comissão), vê os próprios números.
    # colaborador: executa; não vê valores. O que cada um pode está em
    # core/permissions.py (vinculo_do_usuario, exigir_*).
    PARCEIRO = 'parceiro', 'Parceiro'
    COLABORADOR = 'colaborador', 'Colaborador'


class Colaborador(models.Model):
    # O login é opcional: o dono cadastra quem trabalha sem convite e, se um
    # dia quiser dar acesso, convida — o mesmo registro ganha o user.
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='colaborador', null=True, blank=True)
    nome = models.CharField(max_length=150, blank=True)
    funcao = models.CharField(max_length=100, blank=True)
    tipo = models.CharField(max_length=20, choices=VinculoColaborador.choices, default=VinculoColaborador.PARCEIRO)
    # Só para parceiro: a parte dele sobre cada pagamento (0 a 100). Nulo é
    # sem acordo registrado. O valor congela em cada pagamento na cobrança.
    comissao_percentual = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    # Só pesa para o colaborador comum: parceiro e dono cobram sempre.
    pode_cobrar = models.BooleanField(default=True)
    ativo = models.BooleanField(default=True)
    criado_em = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.nome_exibido

    @property
    def tem_acesso(self) -> bool:
        return self.user_id is not None

    @property
    def nome_exibido(self) -> str:
        if self.nome:
            return self.nome
        if self.user_id:
            return self.user.get_full_name() or self.user.email
        return ''

    @property
    def eh_parceiro(self) -> bool:
        return self.tipo == VinculoColaborador.PARCEIRO

    def comissao_para(self, valor: Decimal) -> Decimal:
        """O repasse ao parceiro sobre um valor pago; zero sem acordo."""
        if not self.eh_parceiro or self.comissao_percentual is None:
            return Decimal('0.00')
        return (Decimal(valor) * self.comissao_percentual / Decimal('100')).quantize(Decimal('0.01'))


class ConviteColaborador(models.Model):
    nome = models.CharField(max_length=150, blank=True, default='')
    email = models.EmailField()
    token = models.UUIDField(default=uuid.uuid4, unique=True)
    # Convite para alguém que já está na equipe sem login: ao aceitar, o
    # user entra neste registro em vez de criar outro.
    colaborador = models.ForeignKey(
        Colaborador, on_delete=models.CASCADE, null=True, blank=True, related_name='convites',
    )
    aceito = models.BooleanField(default=False)
    criado_em = models.DateTimeField(auto_now_add=True)
    expira_em = models.DateTimeField()

    def __str__(self):
        return f'Convite → {self.nome} <{self.email}>'
