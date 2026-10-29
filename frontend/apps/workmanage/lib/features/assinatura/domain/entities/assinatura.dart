import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

// o status da assinatura do negócio na plataforma. bloqueada é calculado
// pela API a partir do status e das datas (trial vencido, inadimplente,
// cancelada depois do vencimento); o app não refaz essa conta
enum StatusAssinatura { ativa, cancelada, inadimplente, trial }

extension StatusAssinaturaNomes on StatusAssinatura {
  String get nome => switch (this) {
    StatusAssinatura.ativa => 'Ativa',
    StatusAssinatura.cancelada => 'Cancelada',
    StatusAssinatura.inadimplente => 'Inadimplente',
    StatusAssinatura.trial => 'Período de teste',
  };
}

class Assinatura extends Equatable {
  const Assinatura({
    required this.status,
    required this.planoNome,
    required this.inicio,
    required this.proximoVencimento,
    this.trialFim,
    required this.bloqueada,
    this.checkoutAberto = false,
  });

  final StatusAssinatura status;
  final String planoNome;
  final DateTime inicio;

  // numa cancelada, até quando o acesso ainda vale
  final DateTime proximoVencimento;
  final DateTime? trialFim;
  final bool bloqueada;

  // false enquanto assinar pelo app não está liberado (a fase de testes): a
  // tela mostra "Em breve" e a API recusa com assinatura_em_breve
  final bool checkoutAberto;

  // quando faz sentido oferecer o checkout
  bool get podeAssinar => status != StatusAssinatura.ativa;

  @override
  List<Object?> get props => [
    status,
    planoNome,
    inicio,
    proximoVencimento,
    trialFim,
    bloqueada,
    checkoutAberto,
  ];
}

enum StatusPagamentoAssinatura { pago, pendente, falhou }

extension StatusPagamentoAssinaturaNomes on StatusPagamentoAssinatura {
  String get nome => switch (this) {
    StatusPagamentoAssinatura.pago => 'Pago',
    StatusPagamentoAssinatura.pendente => 'Pendente',
    StatusPagamentoAssinatura.falhou => 'Falhou',
  };
}

// uma cobrança da plataforma ao negócio
class PagamentoAssinatura extends Equatable {
  const PagamentoAssinatura({
    required this.valor,
    required this.status,
    required this.data,
  });

  final Decimal valor;
  final StatusPagamentoAssinatura status;
  final DateTime data;

  @override
  List<Object?> get props => [valor, status, data];
}
