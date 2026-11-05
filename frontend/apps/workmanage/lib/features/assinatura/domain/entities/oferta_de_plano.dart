import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import 'assinatura.dart';

// de quanto em quanto tempo a loja cobra. o semestral existe para o anual
// parecer o melhor negócio: o desconto dele é pequeno
enum PeriodoDoPlano { mensal, semestral, anual }

extension PeriodoDoPlanoNomes on PeriodoDoPlano {
  String get nome => switch (this) {
    PeriodoDoPlano.mensal => 'Mensal',
    PeriodoDoPlano.semestral => 'Semestral',
    PeriodoDoPlano.anual => 'Anual',
  };

  int get meses => switch (this) {
    PeriodoDoPlano.mensal => 1,
    PeriodoDoPlano.semestral => 6,
    PeriodoDoPlano.anual => 12,
  };
}

// um plano num período, com o preço da loja. o preço em texto vem da loja,
// já na moeda e no formato do aparelho; o Decimal serve só para as contas
// (por mês e o desconto). o id é o da loja, e só o data sabe comprar por ele
class OfertaDePlano extends Equatable {
  const OfertaDePlano({
    required this.id,
    required this.plano,
    required this.periodo,
    required this.preco,
    required this.precoTexto,
  });

  final String id;
  final TipoPlano plano;
  final PeriodoDoPlano periodo;
  final Decimal preco;
  final String precoTexto;

  // o preço dividido pelos meses do período, com duas casas
  Decimal get precoPorMes => (preco / Decimal.fromInt(periodo.meses))
      .toDecimal(scaleOnInfinitePrecision: 2)
      .round(scale: 2);

  @override
  List<Object?> get props => [id, plano, periodo, preco, precoTexto];
}

// quanto o período economiza sobre pagar mês a mês, em pontos inteiros
// (17 para 17%). zero no mensal, sem o mensal para comparar ou sem economia
int descontoSobreMensal(OfertaDePlano oferta, OfertaDePlano? mensal) {
  if (mensal == null || oferta.periodo == PeriodoDoPlano.mensal) return 0;
  final cheio = mensal.preco * Decimal.fromInt(oferta.periodo.meses);
  if (cheio <= Decimal.zero || oferta.preco >= cheio) return 0;
  final economia = ((cheio - oferta.preco) / cheio).toDecimal(
    scaleOnInfinitePrecision: 4,
  );
  return (economia * Decimal.fromInt(100)).round().toBigInt().toInt();
}
