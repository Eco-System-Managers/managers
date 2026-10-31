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
    # O que o atendimento custou a mais, acertado com o cliente na hora de
    # cobrar ("tempo excedido"); o motivo é o que ele vê no app. Só a cobrança
    # mexe nos dois — preço é acordo, não ajuste de tela.
    acrescimo = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    acrescimo_motivo = models.CharField(max_length=60, blank=True, default='')
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


class Bloqueio(models.Model):
    """Um período em que o profissional não atende: um imprevisto, uma folga,
    as férias ou a pausa de todo dia (o almoço). É o que substitui pausa fixa
    no expediente: a agenda não reserva intervalo nenhum sozinha.

    Sem colaborador é o **negócio inteiro** que fecha (o almoço de todos, o
    dia que desandou): vale na agenda de todo profissional e na esteira, que
    não tem agenda individual. Só o dono cria e exclui esse.

    "Uma semana" e "um mês" não ficam guardados: são a tela preenchendo a
    `data_fim`.
    """
    colaborador = models.ForeignKey(
        Colaborador, on_delete=models.CASCADE, related_name='bloqueios', null=True, blank=True,
    )
    data_inicio = models.DateField()
    # Nulo é o bloqueio fixo: vale todos os dias a partir do início.
    data_fim = models.DateField(null=True, blank=True)
    # Os dois nulos bloqueiam o dia inteiro.
    hora_inicio = models.TimeField(null=True, blank=True)
    hora_fim = models.TimeField(null=True, blank=True)
    motivo = models.CharField(max_length=60, blank=True)
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['data_inicio', 'hora_inicio']

    def __str__(self):
        return f'{self.colaborador or "Negócio"} — {self.data_inicio:%d/%m/%Y}'
