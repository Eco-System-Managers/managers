import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/financeiro/data/models/cobranca_model.dart';
import 'package:managers/features/financeiro/domain/entities/pagamento.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';

void main() {
  final pix = Pagamento(forma: FormaPagamento.pix, valor: Decimal.fromInt(60));

  test('sem acerto com o cliente, o corpo vai sem acréscimo e sem a troca', () {
    final corpo = corpoDeCobranca(CobrancaParams(id: 3, pagamentos: [pix]));

    expect(corpo, {
      'desconto': '0.00',
      'acrescimo': '0.00',
      'acrescimo_motivo': '',
      'pagamentos': [
        {'forma': 'pix', 'valor': '60.00'},
      ],
      'credito_aplicado': '0.00',
      'troco_credito': '0.00',
    });
    // sem servico_ids a API cobra o serviço combinado
    expect(corpo.containsKey('servico_ids'), isFalse);
  });

  test('o acréscimo vai com o motivo e a troca vai como servico_ids', () {
    final corpo = corpoDeCobranca(
      CobrancaParams(
        id: 3,
        pagamentos: [pix],
        acrescimo: Decimal.parse('12.5'),
        acrescimoMotivo: 'Tempo excedido',
        servicoIds: const [8],
      ),
    );

    expect(corpo['acrescimo'], '12.50');
    expect(corpo['acrescimo_motivo'], 'Tempo excedido');
    expect(corpo['servico_ids'], [8]);
  });

  test('totalPago soma os pagamentos e o crédito aplicado', () {
    final params = CobrancaParams(
      id: 3,
      pagamentos: [pix],
      creditoAplicado: Decimal.fromInt(5),
    );

    expect(params.totalPago, Decimal.fromInt(65));
    expect(params.acrescimo, Decimal.fromInt(0));
    expect(params.servicoIds, isNull);
  });
}
