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
    # A etapa em que o carro ou o pet está pronto. As etapas são do dono, que
    # renomeia e reordena, então quem diz qual é o pronto é ele; as que vêm
    # depois dela também contam. Sem nenhuma marcada vale a última (ver
    # EtapaService.etapa_pronto).
    pronto = models.BooleanField(default=False)
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['ordem']
        verbose_name = 'Etapa'
        verbose_name_plural = 'Etapas'
        constraints = [
            UniqueConstraint(fields=['pronto'], condition=Q(pronto=True), name='kanban_uma_etapa_pronto'),
        ]

    def __str__(self):
        return self.nome


class AtendimentoKanban(models.Model):
    etapa = models.ForeignKey(EtapaKanban, on_delete=models.PROTECT, related_name='atendimentos')
    # O pet ou veículo; o cliente vem por ele. Nulo no avulso: quem chegou e
    # pediu "lava aí" sem cadastro. Cadastrar cliente e carro nessa hora é
    # burocracia que ninguém faz, e um "cliente genérico" viraria o maior
    # cliente do negócio. Sem objeto, a `identificacao` é obrigatória
    # (conferir_identificacao, em services.py).
    objeto = models.ForeignKey(
        ObjetoCliente, on_delete=models.PROTECT, related_name='atendimentos', null=True, blank=True,
    )
    # O texto que diz de quem é o carro ou o pet no pátio ("Hilux branca",
    # "ABC-1234"). É o que identifica o avulso; com objeto costuma ficar vazio.
    identificacao = models.CharField(max_length=80, blank=True, default='')
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
    # O que o atendimento custou a mais, acertado com o cliente na hora de
    # cobrar ("tempo excedido"); o motivo é o que ele vê no app. Só a cobrança
    # mexe nos dois, e desfazê-la zera. O tempo a mais previsto
    # (minutos_extras) não passa por aqui: tempo é do pátio, preço é acordo.
    acrescimo = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    acrescimo_motivo = models.CharField(max_length=60, blank=True, default='')
    # O tempo a mais que o dono previu ("esse vai levar mais 1h"), somado à
    # duração do serviço. É problema do pátio: não mexe no preço.
    minutos_extras = models.PositiveIntegerField(default=0)
    # Quando o card chegou na etapa de pronto; volta a nulo se ele voltar.
    pronto_em = models.DateTimeField(null=True, blank=True)
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['criado_em']
        verbose_name = 'Atendimento'
        verbose_name_plural = 'Atendimentos'

    def __str__(self):
        return f'{self.identificacao if self.avulso else self.objeto} — {self.etapa}'

    @property
    def avulso(self) -> bool:
        """Sem veículo nem pet: só a identificação diz de quem é."""
        return self.objeto_id is None

    @property
    def cliente(self):
        """O cliente vem pelo veículo ou pet; o avulso não tem nenhum. Quem lê
        o atendimento fora do quadro passa por aqui para não cair em
        `None.cliente`."""
        return self.objeto.cliente if self.objeto_id is not None else None

    @property
    def rotulo(self) -> str:
        """Como o atendimento aparece fora do quadro (caixa, painel,
        pendências): o nome do cliente ou, no avulso, a identificação."""
        cliente = self.cliente
        return cliente.nome if cliente is not None else self.identificacao

    @property
    def duracao_prevista(self) -> int:
        """Em minutos: a duração do serviço mais o tempo a mais previsto."""
        return self.servico.duracao + self.minutos_extras


class AjusteDoDia(models.Model):
    """A capacidade de uma data que foge do padrão da semana: a funcionária
    faltou, um freelancer veio. Substitui os dois números do horário daquele
    dia da semana só nesta data; apagar volta ao padrão."""
    data = models.DateField(unique=True)
    # Nulo é sem máximo, como no horário.
    capacidade = models.PositiveIntegerField(null=True, blank=True)
    vagas = models.PositiveIntegerField(default=1)
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Ajuste do dia'
        verbose_name_plural = 'Ajustes do dia'

    def __str__(self):
        return f'Ajuste de {self.data:%d/%m/%Y}'


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
