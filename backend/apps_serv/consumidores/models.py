from django.contrib.auth.hashers import check_password, make_password
from django.db import models

from core.models import CodigoRecuperacaoBase
from apps_work.agenda.models import OrigemAtendimento, StatusAgendamento
from apps_work.clientes.models import TipoObjeto


class Consumidor(models.Model):
    email = models.EmailField(unique=True)
    password = models.CharField(max_length=128)
    nome = models.CharField(max_length=255)
    # Obrigatório, como no Cliente do tenant: é por ele que o negócio fala com
    # quem agendou. Antes era opcional aqui e o vínculo criava cliente sem
    # telefone do outro lado.
    telefone = models.CharField(max_length=20)
    # Ficha completa do cliente. Vive só aqui, no schema público: os negócios
    # vinculados recebem uma cópia sincronizada, nunca a fonte.
    cpf = models.CharField(max_length=14, blank=True)
    data_nascimento = models.DateField(null=True, blank=True)
    cep = models.CharField(max_length=9, blank=True)
    endereco = models.CharField(max_length=255, blank=True)
    numero_endereco = models.CharField(max_length=10, blank=True)
    # Caminho do objeto no armazenamento, não a URL. A foto é privada e o
    # endereço vem assinado com validade curta — guardar a URL faria a imagem
    # parar de abrir sozinha depois de alguns minutos.
    foto_chave = models.CharField(max_length=255, blank=True)
    ativo = models.BooleanField(default=True)
    criado_em = models.DateTimeField(auto_now_add=True)
    # Tokens emitidos antes deste instante deixam de valer — é como a troca de
    # senha derruba todas as sessões, inclusive os access ainda não expirados.
    sessoes_validas_desde = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = 'Consumidor'
        verbose_name_plural = 'Consumidores'

    def __str__(self):
        return f'{self.nome} <{self.email}>'

    # Interface mínima para compatibilidade com DRF IsAuthenticated
    @property
    def is_authenticated(self):
        return True

    def set_password(self, raw_password: str) -> None:
        self.password = make_password(raw_password)

    def check_password(self, raw_password: str) -> bool:
        return check_password(raw_password, self.password)


class CodigoRecuperacaoConsumidor(CodigoRecuperacaoBase):
    CAMPO_DONO = 'consumidor'

    consumidor = models.ForeignKey(Consumidor, on_delete=models.CASCADE, related_name='codigos_recuperacao')

    class Meta(CodigoRecuperacaoBase.Meta):
        verbose_name = 'Código de Recuperação'
        verbose_name_plural = 'Códigos de Recuperação'


class RefreshRevogadoConsumidor(models.Model):
    """Refresh do Service Manage que não vale mais: usado numa renovação ou
    encerrado no logout. Guarda só o `jti`; depois de `expira_em` o token já
    seria recusado pela expiração, e a linha pode ser apagada."""

    jti = models.CharField(max_length=64, unique=True)
    expira_em = models.DateTimeField()
    revogado_em = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.jti


class VinculoConsumidor(models.Model):
    consumidor = models.ForeignKey(Consumidor, on_delete=models.CASCADE, related_name='vinculos')
    schema_name = models.CharField(max_length=63)
    ativo = models.BooleanField(default=True)
    criado_em = models.DateTimeField(auto_now_add=True)
    desvinculado_em = models.DateTimeField(null=True, blank=True)

    class Meta:
        unique_together = ('consumidor', 'schema_name')
        verbose_name = 'Vínculo com negócio'
        verbose_name_plural = 'Vínculos com negócios'

    def __str__(self):
        return f'{self.consumidor.nome} → {self.schema_name} ({"ativo" if self.ativo else "inativo"})'


class ObjetoConsumidor(models.Model):
    consumidor = models.ForeignKey(Consumidor, on_delete=models.CASCADE, related_name='objetos')
    tipo = models.CharField(max_length=20, choices=TipoObjeto.choices)
    dados = models.JSONField()
    nome_exibicao = models.CharField(max_length=255)
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Objeto do Consumidor'
        verbose_name_plural = 'Objetos dos Consumidores'
        ordering = ['-criado_em']

    def __str__(self):
        return f'{self.consumidor.nome} → {self.nome_exibicao}'


class AgendamentoConsumidor(models.Model):
    consumidor = models.ForeignKey(Consumidor, on_delete=models.CASCADE, related_name='agendamentos')
    schema_name = models.CharField(max_length=63)
    agendamento_id = models.PositiveIntegerField()
    origem = models.CharField(max_length=10, choices=OrigemAtendimento.choices, default=OrigemAtendimento.AGENDA)
    negocio_nome = models.CharField(max_length=255)
    nicho = models.CharField(max_length=50, blank=True)
    servicos = models.JSONField(default=list)
    profissional_nome = models.CharField(max_length=255, blank=True)
    data_hora = models.DateTimeField()
    duracao_total = models.PositiveIntegerField(help_text='Duração total em minutos')
    valor_total = models.DecimalField(max_digits=10, decimal_places=2)
    valor_taxa_cancelamento = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    # Espelha o status do agendamento no negócio — inclusive "faltou", que o
    # negócio marca no painel: o cliente precisa saber que constou como falta.
    status = models.CharField(max_length=20, choices=StatusAgendamento.choices, default=StatusAgendamento.AGENDADO)
    objeto_dados = models.JSONField(null=True, blank=True)
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Agendamento do Consumidor'
        verbose_name_plural = 'Agendamentos dos Consumidores'
        ordering = ['-data_hora']

    def __str__(self):
        return f'{self.consumidor.nome} — {self.negocio_nome} — {self.data_hora:%d/%m/%Y %H:%M}'
