import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:managers/core/utils/dinheiro.dart';

// campo de valor em reais: a pessoa digita só dígitos e o campo mostra
// "1.234,56", preenchendo da direita para a esquerda (os centavos primeiro),
// como nos apps de banco. o valor sai com dinheiroDoTexto (core/utils)
class DinheiroInputFormatter extends TextInputFormatter {
  const DinheiroInputFormatter();

  // o texto do campo para um valor que veio da API, ex.: ao editar
  static String formatar(Decimal valor) {
    // formatarDinheiro põe o "R$ "; o campo tem o prefixo na decoração
    return formatarDinheiro(valor).replaceFirst('R\$ ', '');
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return const TextEditingValue();

    // os dígitos são centavos: "4550" -> 45,50
    final centavos = BigInt.parse(digitos);
    final valor = (Decimal.fromBigInt(centavos) / Decimal.fromInt(100))
        .toDecimal(scaleOnInfinitePrecision: 2);
    final texto = formatar(valor);

    // o cursor vai para o fim: a máscara muda o tamanho do texto
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
