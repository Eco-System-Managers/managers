import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/clientes/domain/entities/objeto_cliente.dart';
import 'package:managers/features/financeiro/domain/entities/pagamento.dart';

// o card do quadro: um objeto (veículo ou pet) de um cliente, ou o avulso
// (sem cadastro, só a identificação), um serviço, em alguma etapa. não há
// status: a posição na etapa é o status; falta e pago são marcas à parte
class AtendimentoKanban extends Equatable {
  AtendimentoKanban({
    required this.id,
    required this.etapaId,
    required this.etapaNome,
    this.objeto,
    this.identificacao = '',
    this.clienteNome = '',
    this.clienteTelefone = '',
    required this.servicoId,
    required this.servicoNome,
    required this.servicoPreco,
    this.servicoDuracao = 0,
    this.colaboradorId,
    this.colaboradorNome = '',
    this.observacao = '',
    this.data,
    this.horarioEntrada,
    this.pago = false,
    this.faltou = false,
    Decimal? desconto,
    Decimal? acrescimo,
    this.acrescimoMotivo = '',
    this.pagamentos = const [],
    this.minutosExtras = 0,
    int? duracaoPrevista,
    this.prontoEm,
    this.criadoEm,
  }) : desconto = desconto ?? Decimal.fromInt(0),
       acrescimo = acrescimo ?? Decimal.fromInt(0),
       duracaoPrevista = duracaoPrevista ?? servicoDuracao + minutosExtras;

  final int id;
  final int etapaId;
  final String etapaNome;

  // o veículo ou pet; null no avulso
  final ObjetoCliente? objeto;

  // o avulso: o texto que diz de quem é o carro ou o pet no pátio ("Hilux
  // branca", "ABC-1234"). com objeto costuma vir vazio
  final String identificacao;

  // vazios no avulso: não há cliente
  final String clienteNome;
  final String clienteTelefone;
  final int servicoId;
  final String servicoNome;

  // o preço do catálogo na hora da leitura: a esteira não congela preço
  final Decimal servicoPreco;
  final int servicoDuracao;

  // quem pegou o carro ou o pet; opcional
  final int? colaboradorId;
  final String colaboradorNome;
  final String observacao;

  // o dia do quadro; a API usa hoje quando não vem
  final DateTime? data;

  // opcional: dá para receber sem hora marcada
  final Hora? horarioEntrada;
  final bool pago;
  final bool faltou;
  final Decimal desconto;

  // o valor a mais combinado com o cliente na cobrança e o porquê ("Tempo
  // excedido"); zero e vazio sem acréscimo
  final Decimal acrescimo;
  final String acrescimoMotivo;
  final List<Pagamento> pagamentos;

  // o tempo a mais que o dono prevê, em minutos. é do pátio: segura a vaga
  // por mais tempo e não mexe no preço
  final int minutosExtras;

  // minutos: a duração do serviço mais o tempo a mais
  final int duracaoPrevista;

  // quando o card chegou na etapa de pronto; null antes disso
  final DateTime? prontoEm;
  final DateTime? criadoEm;

  // quem chegou sem cadastro: só o serviço e a identificação. não tem
  // comanda (a API recusa crédito com avulso_sem_credito) nem histórico
  bool get ehAvulso => objeto == null;

  // null no avulso
  int? get clienteId => objeto?.clienteId;

  // o que nomeia o atendimento: o veículo ou pet, ou a identificação do
  // avulso ("Fiat Uno" / "Rex" / "Hilux branca")
  String get titulo => objeto?.titulo ?? identificacao;

  // de quem é: o nome do cliente ou, no avulso, a identificação. é o
  // rotulo do model na API (caixa, painel, pendências)
  String get rotulo => ehAvulso ? identificacao : clienteNome;

  bool get pronto => prontoEm != null;

  // o que foi (ou é) cobrado: o serviço mais o acréscimo, menos o desconto
  Decimal get valorTotal => servicoPreco + acrescimo - desconto;

  // quanto tempo o atendimento levou de verdade, em minutos: da entrada até
  // ficar pronto. null antes de pronto ou sem hora de início conhecida
  int? get minutosLevados {
    final inicio = inicioPrevisto;
    final fim = prontoEm;
    if (inicio == null || fim == null || !fim.isAfter(inicio)) return null;
    return fim.difference(inicio).inMinutes;
  }

  Decimal get valorPago =>
      pagamentos.fold(Decimal.fromInt(0), (soma, p) => soma + p.valor);

  // quando o atendimento começa: o dia com a hora de entrada. sem hora, a
  // chegada (criadoEm), mas só quando ele chegou no dia do atendimento:
  // recebido hoje para amanhã sem hora, não há como saber. null fora disso
  DateTime? get inicioPrevisto {
    final data = this.data;
    final hora = horarioEntrada;
    if (data != null && hora != null) return juntarDataHora(data, hora);
    final chegada = criadoEm;
    if (chegada == null || (data != null && !mesmoDia(data, chegada))) {
      return null;
    }
    return chegada;
  }

  // o início mais a duração prevista (o serviço e o tempo a mais)
  DateTime? get fimPrevisto =>
      inicioPrevisto?.add(Duration(minutes: duracaoPrevista));

  // quantos minutos o atendimento passou do fim previsto, em agora. só vale
  // no dia do atendimento, enquanto ele não ficou pronto, não faltou e não
  // foi pago; sem duração prevista não há o que exceder. zero fora disso
  int atrasoEm(DateTime agora) {
    if (pronto || faltou || pago || duracaoPrevista <= 0) return 0;
    final inicio = inicioPrevisto;
    final fim = fimPrevisto;
    if (inicio == null || fim == null) return 0;
    if (!mesmoDia(inicio, agora) || !agora.isAfter(fim)) return 0;
    return agora.difference(fim).inMinutes;
  }

  @override
  List<Object?> get props => [
    id,
    etapaId,
    etapaNome,
    objeto,
    identificacao,
    clienteNome,
    clienteTelefone,
    servicoId,
    servicoNome,
    servicoPreco,
    servicoDuracao,
    colaboradorId,
    colaboradorNome,
    observacao,
    data,
    horarioEntrada,
    pago,
    faltou,
    desconto,
    acrescimo,
    acrescimoMotivo,
    pagamentos,
    minutosExtras,
    duracaoPrevista,
    prontoEm,
    criadoEm,
  ];
}
