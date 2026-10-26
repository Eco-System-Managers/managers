from django.db import models
from apps_work.clientes.models import Cliente
from apps_work.servicos.models import Servico
from apps_work.usuarios.models import Colaborador


class FormaPagamento(models.TextChoices):
    """Como o cliente pagou o atendimento (agenda e kanban)."""
    DINHEIRO = 'dinheiro', 'Dinheiro'
    PIX = 'pix', 'PIX'
    CREDITO = 'credito', 'Crédito'
    DEBITO = 'debito', 'Débito'
    QR_CODE = 'qr_code', 'QR Code'


class StatusAgendamento(models.TextChoices):
    """Status do agendamento. O AgendamentoConsumidor (B2C) espelha o mesmo."""
    AGENDADO = 'agendado', 'Agendado'
    CONFIRMADO = 'confirmado', 'Confirmado'
    CONCLUIDO = 'concluido', 'Concluído'
    CANCELADO = 'cancelado', 'Cancelado'
    FALTOU = 'faltou', 'Faltou'


class OrigemAtendimento(models.TextChoices):
    """De qual modo de agenda veio o atendimento."""
    AGENDA = 'agenda', 'Agenda'
    KANBAN = 'kanban', 'Kanban'


class Agendamento(models.Model):
    cliente = models.ForeignKey(Cliente, on_delete=models.PROTECT, related_name='agendamentos')
    colaborador = models.ForeignKey(Colaborador, on_delete=models.PROTECT, related_name='agendamentos', null=True, blank=True)
    data_hora = models.DateTimeField()
    status = models.CharField(max_length=20, choices=StatusAgendamento.choices, default=StatusAgendamento.AGENDADO)
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


class PagamentoAgendamento(models.Model):
    agendamento = models.ForeignKey(Agendamento, on_delete=models.CASCADE, related_name='pagamentos')
    forma = models.CharField(max_length=20, choices=FormaPagamento.choices)
    valor = models.DecimalField(max_digits=8, decimal_places=2)
    # A comissão do parceiro na hora da cobrança, congelada: o acordo pode
    # mudar depois sem reescrever o passado. Nulo é sem acordo.
    comissao_percentual = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    repasse = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    criado_em = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.agendamento} — {self.forma}: R${self.valor}'
