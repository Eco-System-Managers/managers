import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

// o saldo de crédito do cliente dentro deste negócio (não é carteira: é a
// comanda), somado do extrato a cada consulta
class SaldoCliente extends Equatable {
  const SaldoCliente({required this.saldo, required this.transacoes});

  final Decimal saldo;
  final List<TransacaoCredito> transacoes;

  @override
  List<Object?> get props => [saldo, transacoes];
}

class TransacaoCredito extends Equatable {
  const TransacaoCredito({
    required this.id,
    required this.credito,
    required this.valor,
    required this.origem,
    required this.descricao,
    required this.criadoEm,
  });

  final int id;

  // true: entrou; false: saiu
  final bool credito;
  final Decimal valor;

  // troco, manual, b2c, desconto_aplicado, taxa_cancelamento
  final String origem;
  final String descricao;
  final DateTime criadoEm;

  String get origemNome => switch (origem) {
    'troco' => 'Troco de atendimento',
    'manual' => 'Lançamento manual',
    'b2c' => 'Crédito do app',
    'desconto_aplicado' => 'Desconto de saldo',
    'taxa_cancelamento' => 'Taxa de cancelamento',
    _ => origem,
  };

  @override
  List<Object?> get props => [id, credito, valor, origem, descricao, criadoEm];
}
