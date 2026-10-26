from django.db import models
from django.db.models import Q, UniqueConstraint
from apps_work.agenda.models import FormaPagamento
from apps_work.clientes.models import ObjetoCliente
from apps_work.servicos.models import Servico
from apps_work.usuarios.models import Colaborador


class EtapaKanban(models.Model):
    nome = models.CharField(max_length=100)
    ordem = models.PositiveIntegerField(default=0)
    cor = models.CharField(max_length=7, blank=True, default='')
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['ordem']
        verbose_name = 'Etapa'
        verbose_name_plural = 'Etapas'

    def __str__(self):
        return self.nome


class AtendimentoKanban(models.Model):
    etapa = models.ForeignKey(EtapaKanban, on_delete=models.PROTECT, related_name='atendimentos')
    objeto = models.ForeignKey(ObjetoCliente, on_delete=models.PROTECT, related_name='atendimentos')
    servico = models.ForeignKey(Servico, on_delete=models.PROTECT, related_name='atendimentos_kanban')
    # Quem pegou o carro ou o pet. Opcional: a esteira funciona sem dono do
    # card; com ele, o quadro, o caixa e o painel filtram por profissional.
    colaborador = models.ForeignKey(
        Colaborador, on_delete=models.PROTECT, related_name='atendimentos_kanban', null=True, blank=True,
    )
    observacao = models.TextField(blank=True, default='')
    data = models.DateField(null=True, blank=True)
    horario_entrada = models.TimeField(null=True, blank=True)
    pago = models.BooleanField(default=False)
    # Quem não apareceu. Não vira coluna do quadro: as etapas são livres e o
    # status que o cliente enxerga é derivado da posição delas, então falta
    # precisa ser um estado à parte do avanço normal do atendimento.
    faltou = models.BooleanField(default=False)
    desconto = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['criado_em']
        verbose_name = 'Atendimento'
        verbose_name_plural = 'Atendimentos'
        constraints = [
            # Impede dois atendimentos no mesmo horário — só se aplica quando
            # data e horário foram de fato escolhidos (ambos são opcionais).
            UniqueConstraint(
                fields=['data', 'horario_entrada'],
                condition=Q(data__isnull=False, horario_entrada__isnull=False),
                name='kanban_atendimento_unique_slot',
            ),
        ]

    def __str__(self):
        return f'{self.objeto} — {self.etapa}'


class PagamentoAtendimento(models.Model):
    atendimento = models.ForeignKey(AtendimentoKanban, on_delete=models.CASCADE, related_name='pagamentos')
    forma = models.CharField(max_length=20, choices=FormaPagamento.choices)
    valor = models.DecimalField(max_digits=8, decimal_places=2)
    # A comissão do parceiro na hora da cobrança, congelada (ver agenda).
    comissao_percentual = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    repasse = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    criado_em = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.atendimento} — {self.forma}: R${self.valor}'
