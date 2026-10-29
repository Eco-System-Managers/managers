from django.contrib.postgres.fields import ArrayField
from django.db import models

from apps_work.clientes.models import TipoObjeto


class TipoAgenda(models.TextChoices):
    """Os dois modos de agenda. Ver apps_work/CLAUDE.md."""
    HORARIO = 'horario', 'Por horário'
    KANBAN = 'kanban', 'Esteira / Kanban'


class TipoDocumento(models.TextChoices):
    CPF = 'cpf', 'CPF'
    CNPJ = 'cnpj', 'CNPJ'


class Nicho(models.TextChoices):
    """O ramo do negócio. Nos nichos conhecidos, define o tipo de agenda e o
    objeto que o cliente leva (mapas do ModoAgendaService, em
    services.py). Em OUTRO, quem escolhe os dois é o dono, e o ramo vai por
    extenso em `nicho_descricao`. Os rótulos exibidos ao usuário vivem nos
    apps.

    A ordem aqui é a ordem de exibição: os nichos de um negócio são guardados
    e mostrados nela, sem um principal."""
    CABELEIREIRO = 'cabeleireiro', 'Cabeleireiro(a)'
    BARBEARIA = 'barbearia', 'Barbearia'
    MANICURE = 'manicure', 'Manicure'
    PEDICURE = 'pedicure', 'Pedicure'
    DEPILACAO = 'depilacao', 'Depilação'
    DESIGN_SOBRANCELHAS = 'design_sobrancelhas', 'Design de sobrancelhas'
    MICROPIGMENTACAO = 'micropigmentacao', 'Micropigmentação'
    CILIOS = 'cilios', 'Cílios'
    MAQUIAGEM = 'maquiagem', 'Maquiagem'
    MASSAGEM = 'massagem', 'Massagem'
    LAVA_RAPIDO = 'lava_rapido', 'Lava-rápido'
    BANHO_TOSA = 'banho_tosa', 'Banho e Tosa'
    OUTRO = 'outro', 'Outro'


class DiaSemana(models.IntegerChoices):
    SEGUNDA = 0, 'Segunda-feira'
    TERCA = 1, 'Terça-feira'
    QUARTA = 2, 'Quarta-feira'
    QUINTA = 3, 'Quinta-feira'
    SEXTA = 4, 'Sexta-feira'
    SABADO = 5, 'Sábado'
    DOMINGO = 6, 'Domingo'


class EmpresaConfig(models.Model):
    nome = models.CharField(max_length=255, blank=True)
    telefone = models.CharField(max_length=20, blank=True)
    # Guardado só com os dígitos; a formatação fica na interface. Fica blank
    # porque a linha nasce vazia no primeiro GET (get_or_create) — quem exige
    # o documento é o serializer, ao concluir o onboarding.
    documento = models.CharField(max_length=14, blank=True)
    tipo_documento = models.CharField(max_length=4, choices=TipoDocumento.choices, blank=True)
    # De 1 a 4 nichos da mesma área, na ordem do enum. Vazio só antes de o
    # onboarding escolher. As regras estão no ModoAgendaService.
    nichos = ArrayField(models.CharField(max_length=50, choices=Nicho.choices), default=list, blank=True)
    # O ramo por extenso, quando nenhum nicho da lista serve (nichos = [OUTRO]).
    # Vazio nos demais.
    nicho_descricao = models.CharField(max_length=60, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    logo_url = models.URLField(blank=True)
    cidade = models.CharField(max_length=100, blank=True)
    endereco = models.CharField(max_length=255, blank=True)
    # Separado do endereço para o geocodificador receber "rua, número" sem a
    # interface precisar montar o texto. Vazio quando não há número.
    numero = models.CharField(max_length=20, blank=True)
    # Guardados só com os dígitos / a sigla. Alimentam a geocodificação: sem UF
    # a busca depende de "cidade + Brasil" desambiguar sozinha, e existe mais de
    # uma Araras no país.
    cep = models.CharField(max_length=8, blank=True)
    uf = models.CharField(max_length=2, blank=True)
    # Marcado quando a coordenada chega pronta da interface — o dono apontou o
    # ponto no mapa. A partir daí o geocodificador automático não sobrescreve
    # mais: nenhum serviço gratuito acerta o número no Brasil (o Nominatim erra
    # ~1,3 km no endereço de teste), então o pino do dono é a fonte de verdade.
    localizacao_confirmada = models.BooleanField(default=False)
    tipo_agenda = models.CharField(max_length=10, choices=TipoAgenda.choices, default=TipoAgenda.HORARIO)
    # O que o cliente deixa no negócio, no modo kanban: o card do quadro é
    # sempre um objeto. Vazio no modo horário.
    tipo_objeto = models.CharField(max_length=10, choices=TipoObjeto.choices, blank=True)
    onboarding_concluido = models.BooleanField(default=False)
    atualizado_em = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Configuração da empresa'

    def __str__(self):
        return self.nome or 'Empresa sem nome'

    @property
    def endereco_completo(self) -> str:
        """Rua e número juntos ("Rua Um, 10"), como o geocodificador espera."""
        return ', '.join(parte for parte in (self.endereco, self.numero) if parte)


class HorarioFuncionamento(models.Model):
    dia = models.IntegerField(choices=DiaSemana.choices, unique=True)
    abertura = models.TimeField(null=True, blank=True)
    fechamento = models.TimeField(null=True, blank=True)
    ativo = models.BooleanField(default=True)
    capacidade = models.PositiveIntegerField(null=True, blank=True)

    class Meta:
        ordering = ['dia']

    def __str__(self):
        return self.get_dia_display()
