from django.db import models
from apps_work.clientes.models import Cliente
from apps_work.servicos.models import Servico
from apps_work.usuarios.models import Colaborador

FORMAS_PAGAMENTO = [
    ('dinheiro', 'Dinheiro'),
    ('pix', 'PIX'),
    ('credito', 'Crédito'),
    ('debito', 'Débito'),
    ('qr_code', 'QR Code'),
]


class Agendamento(models.Model):
    STATUS_CHOICES = [
        ('agendado', 'Agendado'),
        ('confirmado', 'Confirmado'),
        ('concluido', 'Concluído'),
        ('cancelado', 'Cancelado'),
        ('faltou', 'Faltou'),
    ]

    cliente = models.ForeignKey(Cliente, on_delete=models.PROTECT, related_name='agendamentos')
    colaborador = models.ForeignKey(Colaborador, on_delete=models.PROTECT, related_name='agendamentos', null=True, blank=True)
    data_hora = models.DateTimeField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='agendado')
    desconto = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    observacoes = models.TextField(blank=True)
    criado_em = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.cliente} — {self.data_hora:%d/%m/%Y %H:%M}'


class AgendamentoServico(models.Model):
    agendamento = models.ForeignKey(Agendamento, on_delete=models.CASCADE, related_name='servicos')
    servico = models.ForeignKey(Servico, on_delete=models.PROTECT)
    preco_cobrado = models.DecimalField(max_digits=8, decimal_places=2)
    desconto = models.DecimalField(max_digits=8, decimal_places=2, default=0)

    def __str__(self):
        return f'{self.agendamento} — {self.servico}'


class Pagamento(models.Model):
    agendamento = models.ForeignKey(Agendamento, on_delete=models.CASCADE, related_name='pagamentos')
    forma = models.CharField(max_length=20, choices=FORMAS_PAGAMENTO)
    valor = models.DecimalField(max_digits=8, decimal_places=2)
    criado_em = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.agendamento} — {self.forma}: R${self.valor}'
