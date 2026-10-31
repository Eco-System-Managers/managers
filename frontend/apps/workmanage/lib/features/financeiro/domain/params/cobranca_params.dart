import 'package:decimal/decimal.dart';

import '../entities/pagamento.dart';

// a cobrança de um atendimento (agenda ou kanban): as formas e valores, o
// desconto, o crédito da comanda usado e o troco que fica como crédito. o
// que se acerta com o cliente na hora de cobrar também vai aqui: o acréscimo
// com o motivo e a troca do serviço pelo que foi feito de verdade. a API
// exige que pagamentos + crédito aplicado feche com serviços (depois da
// troca) + acréscimo - desconto (soma_invalida)
class CobrancaParams {
  CobrancaParams({
    required this.id,
    required this.pagamentos,
    Decimal? desconto,
    Decimal? creditoAplicado,
    Decimal? trocoCredito,
    Decimal? acrescimo,
    this.acrescimoMotivo = '',
    this.servicoIds,
  }) : desconto = desconto ?? Decimal.fromInt(0),
       creditoAplicado = creditoAplicado ?? Decimal.fromInt(0),
       trocoCredito = trocoCredito ?? Decimal.fromInt(0),
       acrescimo = acrescimo ?? Decimal.fromInt(0);

  final int id;
  final List<Pagamento> pagamentos;
  final Decimal desconto;
  final Decimal creditoAplicado;
  final Decimal trocoCredito;

  // o valor a mais combinado com o cliente (tempo excedido, sujeira pesada)
  // e o porquê, que o cliente vê no app dele. zero e vazio sem acréscimo
  final Decimal acrescimo;
  final String acrescimoMotivo;

  // os serviços feitos de verdade, no lugar dos combinados: na esteira um
  // id só; na agenda a lista substitui os serviços. null cobra o combinado
  final List<int>? servicoIds;

  Decimal get totalPago =>
      pagamentos.fold(Decimal.fromInt(0), (soma, p) => soma + p.valor) +
      creditoAplicado;
}
