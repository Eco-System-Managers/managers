import 'package:decimal/decimal.dart';

// dinheiro vai e volta na API como string com duas casas, "45.50"
// (backend/openapi/README.md). Decimal, nunca double: 0.1 + 0.2 em double
// não dá 0.3, e isso apareceria no caixa

Decimal dinheiroDaApi(String valor) => Decimal.parse(valor);

String dinheiroParaApi(Decimal valor) => valor.toStringAsFixed(2);

// o que a pessoa digita num campo de valor: "1.234,50", "1234,5", "45"
Decimal? dinheiroDoTexto(String texto) {
  final limpo = texto.trim().replaceAll('R\$', '').replaceAll('.', '').trim();
  if (limpo.isEmpty) return null;
  return Decimal.tryParse(limpo.replaceAll(',', '.'));
}

// "R$ 1.234,50", sem passar por double: separa a parte inteira dos
// centavos no texto e põe os pontos de milhar à mão
String formatarDinheiro(Decimal valor) {
  final negativo = valor < Decimal.fromInt(0);
  final texto = (negativo ? -valor : valor).toStringAsFixed(2);
  final partes = texto.split('.');
  final inteiro = partes[0];
  final centavos = partes[1];

  final milhares = StringBuffer();
  for (var i = 0; i < inteiro.length; i++) {
    final restantes = inteiro.length - i;
    if (i > 0 && restantes % 3 == 0) milhares.write('.');
    milhares.write(inteiro[i]);
  }

  return '${negativo ? '-' : ''}R\$ $milhares,$centavos';
}
