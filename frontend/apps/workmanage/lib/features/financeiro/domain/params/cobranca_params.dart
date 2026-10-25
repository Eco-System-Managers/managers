import 'package:decimal/decimal.dart';

import '../entities/pagamento.dart';

// a cobrança de um atendimento (agenda ou kanban): as formas e valores, o desconto, o crédito
// da comanda usado e o troco que fica como crédito. a API exige que
// pagamentos + crédito aplicado feche com serviços - desconto (soma_invalida)
class CobrancaParams {
  CobrancaParams({
    required this.id,
    required this.pagamentos,
    Decimal? desconto,
    Decimal? creditoAplicado,
    Decimal? trocoCredito,
  }) : desconto = desconto ?? Decimal.fromInt(0),
       creditoAplicado = creditoAplicado ?? Decimal.fromInt(0),
       trocoCredito = trocoCredito ?? Decimal.fromInt(0);

  final int id;
  final List<Pagamento> pagamentos;
  final Decimal desconto;
  final Decimal creditoAplicado;
  final Decimal trocoCredito;

  Decimal get totalPago =>
      pagamentos.fold(Decimal.fromInt(0), (soma, p) => soma + p.valor) +
      creditoAplicado;
}
