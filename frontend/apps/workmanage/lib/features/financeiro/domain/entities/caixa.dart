import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

// o fechamento de caixa de um período: os números, o total por forma de
// pagamento e cada pagamento. junta os dois modos de agenda
class Caixa extends Equatable {
  Caixa({
    required this.total,
    required this.ticketMedio,
    required this.atendimentos,
    required this.porForma,
    required this.pagamentos,
    Decimal? repasse,
    this.casa,
  }) : repasse = repasse ?? Decimal.zero;

  final Decimal total;
  final Decimal ticketMedio;
  final int atendimentos;

  // a parte dos parceiros, congelada em cada pagamento na cobrança
  final Decimal repasse;

  // total - repasse; null para o parceiro, que vê só a parte dele
  final Decimal? casa;
  final List<CaixaPorForma> porForma;
  final List<CaixaPagamento> pagamentos;

  @override
  List<Object?> get props => [
    total,
    ticketMedio,
    atendimentos,
    repasse,
    casa,
    porForma,
    pagamentos,
  ];
}

class CaixaPorForma extends Equatable {
  const CaixaPorForma({
    required this.forma,
    required this.total,
    required this.percentual,
  });

  // o slug da API (dinheiro, pix, credito, debito, qr_code)
  final String forma;
  final Decimal total;
  final int percentual;

  @override
  List<Object?> get props => [forma, total, percentual];
}

class CaixaPagamento extends Equatable {
  const CaixaPagamento({
    required this.origemAgenda,
    required this.clienteNome,
    required this.servicoNome,
    required this.colaboradorNome,
    required this.forma,
    required this.valor,
    required this.dataHora,
  });

  final bool origemAgenda;
  final String clienteNome;
  final String servicoNome;

  // vazio quando o atendimento não tem profissional
  final String colaboradorNome;
  final String forma;
  final Decimal valor;
  final DateTime dataHora;

  @override
  List<Object?> get props => [
    origemAgenda,
    clienteNome,
    servicoNome,
    colaboradorNome,
    forma,
    valor,
    dataHora,
  ];
}

// o nome da forma de pagamento para a tela, a partir do slug da API
String nomeDaForma(String forma) => switch (forma) {
  'dinheiro' => 'Dinheiro',
  'pix' => 'PIX',
  'credito' => 'Crédito',
  'debito' => 'Débito',
  'qr_code' => 'QR Code',
  _ => forma,
};
