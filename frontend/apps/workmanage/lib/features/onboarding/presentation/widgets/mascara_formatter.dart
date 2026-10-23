import 'package:flutter/services.dart';

// aplica uma máscara enquanto o usuário digita. cada # é um dígito; o resto
// é copiado como está. ex.: '#####-###' transforma 01310100 em 01310-100
class MascaraFormatter extends TextInputFormatter {
  MascaraFormatter(this.mascara) : _mascaraPara = null;

  // para campos com mais de um formato (telefone fixo ou celular): a máscara
  // é escolhida pela quantidade de dígitos digitados
  MascaraFormatter.dinamica(String Function(int digitos) mascaraPara)
    : mascara = '',
      _mascaraPara = mascaraPara;

  final String mascara;
  final String Function(int digitos)? _mascaraPara;

  static const telefone = _telefone;
  static const cep = '#####-###';
  static const cpf = '###.###.###-##';
  static const cnpj = '##.###.###/####-##';

  static String _telefone(int digitos) =>
      digitos <= 10 ? '(##) ####-####' : '(##) #####-####';

  // devolve o texto já formatado; útil para preencher um campo com o valor
  // salvo, que vem só com os dígitos
  String aplicar(String texto) {
    final digitos = texto.replaceAll(RegExp(r'\D'), '');
    final padrao = _mascaraPara?.call(digitos.length) ?? mascara;

    final saida = StringBuffer();
    var i = 0;
    for (final caractere in padrao.split('')) {
      if (i >= digitos.length) break;
      if (caractere == '#') {
        saida.write(digitos[i]);
        i++;
      } else {
        saida.write(caractere);
      }
    }
    return saida.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final texto = aplicar(newValue.text);
    // o cursor vai para o fim: a máscara muda o tamanho do texto
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
