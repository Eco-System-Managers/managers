import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

// o dinheiro que entra num atendimento, nos dois modos de agenda. o
// financeiro é o dono: agenda e kanban só usam

// como o cliente pagou. um atendimento aceita mais de uma forma
enum FormaPagamento { dinheiro, pix, credito, debito, qrCode }

extension FormaPagamentoNomes on FormaPagamento {
  String get nome => switch (this) {
    FormaPagamento.dinheiro => 'Dinheiro',
    FormaPagamento.pix => 'PIX',
    FormaPagamento.credito => 'Crédito',
    FormaPagamento.debito => 'Débito',
    FormaPagamento.qrCode => 'QR Code',
  };

  // o valor do enum na API (qr_code)
  String get slug => this == FormaPagamento.qrCode ? 'qr_code' : name;

  static FormaPagamento? daApi(String slug) {
    return FormaPagamento.values.where((f) => f.slug == slug).firstOrNull;
  }
}

// uma forma e um valor; um atendimento aceita várias
class Pagamento extends Equatable {
  const Pagamento({required this.forma, required this.valor});

  final FormaPagamento forma;
  final Decimal valor;

  @override
  List<Object?> get props => [forma, valor];
}
