import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/dinheiro_input_formatter.dart';

void main() {
  const formatter = DinheiroInputFormatter();

  String digitar(String texto) {
    return formatter
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: texto))
        .text;
  }

  test('os dígitos entram como centavos, da direita para a esquerda', () {
    expect(digitar('4'), '0,04');
    expect(digitar('45'), '0,45');
    expect(digitar('455'), '4,55');
    expect(digitar('4550'), '45,50');
    expect(digitar('123456'), '1.234,56');
  });

  test('ignora o que não é dígito e aceita campo vazio', () {
    expect(digitar('R\$ 45,50'), '45,50');
    expect(digitar(''), '');
  });

  test('o texto formatado volta ao mesmo Decimal', () {
    expect(dinheiroDoTexto(digitar('123456')), Decimal.parse('1234.56'));
  });

  test('formatar preenche o campo com um valor da API', () {
    expect(
      DinheiroInputFormatter.formatar(Decimal.parse('1234.5')),
      '1.234,50',
    );
    expect(DinheiroInputFormatter.formatar(Decimal.fromInt(30)), '30,00');
  });
}
