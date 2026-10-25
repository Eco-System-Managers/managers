import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:managers/features/financeiro/domain/entities/pagamento.dart';

// o ciclo de um agendamento. cancelado some da lista do dia; faltou é
// estado à parte; concluído é o que a cobrança deixa
enum StatusAgendamento { agendado, confirmado, concluido, cancelado, faltou }

// um serviço dentro do agendamento, com o preço congelado na hora de marcar
class ServicoAgendado extends Equatable {
  const ServicoAgendado({
    required this.id,
    required this.servicoId,
    required this.nome,
    required this.duracao,
    required this.precoCobrado,
    required this.desconto,
  });

  final int id;
  final int servicoId;
  final String nome;

  // em minutos
  final int duracao;
  final Decimal precoCobrado;
  final Decimal desconto;

  @override
  List<Object?> get props => [
    id,
    servicoId,
    nome,
    duracao,
    precoCobrado,
    desconto,
  ];
}

// o compromisso: cliente, profissional, data e hora, status. a duração vem
// dos serviços, não do agendamento
class Agendamento extends Equatable {
  Agendamento({
    required this.id,
    required this.clienteId,
    required this.clienteNome,
    this.clienteTelefone = '',
    this.colaboradorId,
    this.colaboradorNome,
    required this.dataHora,
    this.status = StatusAgendamento.agendado,
    Decimal? desconto,
    this.observacoes = '',
    this.servicos = const [],
    this.pagamentos = const [],
    this.criadoEm,
  }) : desconto = desconto ?? Decimal.fromInt(0);

  final int id;
  final int clienteId;
  final String clienteNome;
  final String clienteTelefone;

  // null: sem profissional, não há conflito de agenda a checar
  final int? colaboradorId;
  final String? colaboradorNome;

  // em horário local
  final DateTime dataHora;
  final StatusAgendamento status;
  final Decimal desconto;
  final String observacoes;
  final List<ServicoAgendado> servicos;
  final List<Pagamento> pagamentos;
  final DateTime? criadoEm;

  int get duracaoTotal => servicos.fold(0, (soma, s) => soma + s.duracao);

  DateTime get fim => dataHora.add(Duration(minutes: duracaoTotal));

  // o que seria cobrado sem o desconto do agendamento
  Decimal get valorDosServicos => servicos.fold(
    Decimal.fromInt(0),
    (soma, s) => soma + s.precoCobrado - s.desconto,
  );

  Decimal get valorTotal => valorDosServicos - desconto;

  Decimal get valorPago =>
      pagamentos.fold(Decimal.fromInt(0), (soma, p) => soma + p.valor);

  bool get pago => pagamentos.isNotEmpty;

  // o que ainda cabe fazer com ele
  bool get aberto =>
      status == StatusAgendamento.agendado ||
      status == StatusAgendamento.confirmado;

  @override
  List<Object?> get props => [
    id,
    clienteId,
    clienteNome,
    clienteTelefone,
    colaboradorId,
    colaboradorNome,
    dataHora,
    status,
    desconto,
    observacoes,
    servicos,
    pagamentos,
    criadoEm,
  ];
}
