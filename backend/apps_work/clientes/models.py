from django.db import models


class OrigemCliente(models.TextChoices):
    MANUAL = 'manual', 'Cadastrado pelo negócio'
    SERVICEMANAGE = 'servicemanage', 'Veio do Service Manage'


class TipoObjeto(models.TextChoices):
    """O que o negócio atende no modo kanban. Mesmo conjunto no B2C."""
    VEICULO = 'veiculo', 'Veículo'
    PET = 'pet', 'Pet'


class PortePet(models.TextChoices):
    PEQUENO = 'pequeno', 'Pequeno'
    MEDIO = 'medio', 'Médio'
    GRANDE = 'grande', 'Grande'
    GIGANTE = 'gigante', 'Gigante'


class Cliente(models.Model):
    # Atalhos mantidos para os testes, que ainda usam Cliente.ORIGEM_*.
    ORIGEM_MANUAL = OrigemCliente.MANUAL
    ORIGEM_SERVICEMANAGE = OrigemCliente.SERVICEMANAGE

    nome = models.CharField(max_length=255)
    # Obrigatório: é por ele que o negócio fala com o cliente (WhatsApp,
    # confirmação, cobrança). blank=False vale para formulário e serializer —
    # cadastros antigos sem telefone continuam no banco, mas não passam numa
    # próxima edição.
    telefone = models.CharField(max_length=20)
    email = models.EmailField(blank=True)
    cpf = models.CharField(max_length=14, blank=True)
    data_nascimento = models.DateField(null=True, blank=True)
    cep = models.CharField(max_length=9, blank=True)
    endereco = models.CharField(max_length=255, blank=True)
    numero_endereco = models.CharField(max_length=10, blank=True)

    observacao = models.TextField(blank=True)
    # Espelho da foto do consumidor, no mesmo formato: caminho, não URL. Chega
    # pela sincronização do vínculo e some quando ele é desfeito.
    foto_chave = models.CharField(max_length=255, blank=True)

    # Beleza
    alergia = models.TextField(blank=True)

    # Saúde
    convenio = models.CharField(max_length=100, blank=True)
    carteirinha = models.CharField(max_length=50, blank=True)
    plano = models.CharField(max_length=100, blank=True)
    validade_plano = models.DateField(null=True, blank=True)

    # Controla se o cliente aparece na listagem -- fica False quando o
    # consumidor (Service Manage) se desvincula do negócio. O registro nunca
    # é apagado (retenção fiscal/legal); volta a True se ele se vincular de novo.
    visivel = models.BooleanField(default=True)

    # De onde veio o cadastro. Quem nasceu no Service Manage não pode ser
    # apagado pelo painel sem desfazer o vínculo do consumidor no schema
    # público — senão o negócio continua em "Seus negócios" e o cliente
    # ressurge na lista no próximo agendamento.
    origem = models.CharField(max_length=20, choices=OrigemCliente.choices, default=OrigemCliente.MANUAL)

    # Quem e esta pessoa no schema publico. E a identidade estavel do par
    # consumidor-cliente: antes disso o par era encontrado pelo e-mail, o que
    # amarrava a ligacao a um dado que a pessoa pode querer trocar.
    #
    # Referencia solta, sem ForeignKey, de proposito: um FK de verdade
    # atravessaria schemas (tenant apontando para public) e amarraria a
    # migration de cada tenant a tabela publica. Mesmo padrao que
    # AgendamentoConsumidor.agendamento_id usa na direcao contraria.
    #
    # Nulo em dois casos legitimos: cadastro feito na mao pelo negocio, e
    # registro anterior ao backfill que ainda nao foi acessado.
    consumidor_id = models.PositiveIntegerField(null=True, blank=True, unique=True, db_index=True)

    criado_em = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.nome


class ObjetoCliente(models.Model):
    cliente = models.ForeignKey(Cliente, on_delete=models.CASCADE, related_name='objetos')
    tipo = models.CharField(max_length=20, choices=TipoObjeto.choices)
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-criado_em']

    def __str__(self):
        return f'{self.get_tipo_display()} — {self.cliente}'


class Veiculo(ObjetoCliente):
    placa = models.CharField(max_length=10)
    marca = models.CharField(max_length=50)
    modelo = models.CharField(max_length=100)
    cor = models.CharField(max_length=50)

    def __str__(self):
        return f'{self.marca} {self.modelo} ({self.placa})'


class Pet(ObjetoCliente):
    nome = models.CharField(max_length=100)
    especie = models.CharField(max_length=50, blank=True)
    raca = models.CharField(max_length=100, blank=True)
    porte = models.CharField(max_length=10, choices=PortePet.choices, blank=True)
    data_nascimento = models.DateField(null=True, blank=True)

    def __str__(self):
        return self.nome
