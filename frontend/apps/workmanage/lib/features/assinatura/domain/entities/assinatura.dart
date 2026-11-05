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

// os planos, do menor para o maior. o que cabe em cada um (a equipe, sem
// contar o dono) é regra da API: o limite vem em Assinatura.limiteEquipe e a
// API recusa passar dele com limite_da_equipe
enum TipoPlano { pro, business, enterprise }

extension TipoPlanoNomes on TipoPlano {
  String get nome => switch (this) {
    TipoPlano.pro => 'Pro',
    TipoPlano.business => 'Business',
    TipoPlano.enterprise => 'Enterprise',
  };

  String get descricao => switch (this) {
    TipoPlano.pro => 'Só você, sem equipe',
    TipoPlano.business => 'Você e até 5 pessoas na equipe',
    TipoPlano.enterprise => 'Você e até 10 pessoas na equipe',
  };

  // quantas pessoas cabem na equipe, para escolher o plano antes de comprar
  int get limiteDaEquipe => switch (this) {
    TipoPlano.pro => 0,
    TipoPlano.business => 5,
    TipoPlano.enterprise => 10,
  };
}

// os planos que comportam a equipe de hoje: quem tem equipe não vê o Pro
List<TipoPlano> planosQueCabem(int equipeAtiva) =>
    TipoPlano.values.where((p) => p.limiteDaEquipe >= equipeAtiva).toList();

class Assinatura extends Equatable {
  const Assinatura({
    required this.status,
    required this.planoNome,
    required this.inicio,
    required this.proximoVencimento,
    this.trialFim,
    required this.bloqueada,
    this.checkoutAberto = false,
    this.plano,
    this.vitalicia = false,
    this.limiteEquipe = 0,
    this.equipeAtiva = 0,
  });

  final StatusAssinatura status;
  final String planoNome;
  final DateTime inicio;

  // numa cancelada, até quando o acesso ainda vale
  final DateTime proximoVencimento;
  final DateTime? trialFim;
  final bool bloqueada;

  // false enquanto assinar pelo app não está liberado (a fase de testes): a
  // tela não fala de venda
  final bool checkoutAberto;

  // o plano que vale agora: o teste é business e o vitalício é enterprise
  final TipoPlano? plano;

  // acesso para sempre, concedido por nós (os testadores): nada a comprar
  final bool vitalicia;

  // quantas pessoas cabem na equipe e quantas estão ativas, sem o dono
  final int limiteEquipe;
  final int equipeAtiva;

  // quando faz sentido oferecer os planos para assinar; ativa, a tela
  // oferece trocar de plano
  bool get podeAssinar => !vitalicia && status != StatusAssinatura.ativa;

  @override
  List<Object?> get props => [
    status,
    planoNome,
    inicio,
    proximoVencimento,
    trialFim,
    bloqueada,
    checkoutAberto,
    plano,
    vitalicia,
    limiteEquipe,
    equipeAtiva,
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
