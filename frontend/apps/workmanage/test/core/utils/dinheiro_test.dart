import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/utils/dinheiro.dart';

void main() {
  test('vai e volta da API como string com duas casas', () {
    final valor = dinheiroDaApi('45.50');
    expect(valor, Decimal.parse('45.5'));
    expect(dinheiroParaApi(valor), '45.50');
    expect(dinheiroParaApi(Decimal.fromInt(10)), '10.00');
  });

  test('soma sem o erro do double', () {
    final total = dinheiroDaApi('0.10') + dinheiroDaApi('0.20');
    expect(dinheiroParaApi(total), '0.30');
  });

  test('formata em reais, com milhar e vírgula', () {
    expect(formatarDinheiro(dinheiroDaApi('0.00')), 'R\$ 0,00');
    expect(formatarDinheiro(dinheiroDaApi('45.50')), 'R\$ 45,50');
    expect(formatarDinheiro(dinheiroDaApi('1234.50')), 'R\$ 1.234,50');
    expect(formatarDinheiro(dinheiroDaApi('1234567.89')), 'R\$ 1.234.567,89');
    expect(formatarDinheiro(dinheiroDaApi('-12.00')), '-R\$ 12,00');
  });

  test('lê o que a pessoa digita', () {
    expect(dinheiroDoTexto('1.234,50'), Decimal.parse('1234.5'));
    expect(dinheiroDoTexto('45'), Decimal.fromInt(45));
    expect(dinheiroDoTexto('R\$ 45,5'), Decimal.parse('45.5'));
    expect(dinheiroDoTexto(''), isNull);
    expect(dinheiroDoTexto('abc'), isNull);
  });
}
