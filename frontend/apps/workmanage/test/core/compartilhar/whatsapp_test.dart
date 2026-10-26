import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/compartilhar/whatsapp.dart';

void main() {
  test('o número ganha o DDI do Brasil quando vem só com DDD', () {
    expect(numeroParaWhatsApp('(11) 99999-8888'), '5511999998888');
    expect(numeroParaWhatsApp('1133334444'), '551133334444');
    expect(numeroParaWhatsApp('+55 11 99999-8888'), '5511999998888');
  });

  test('o link leva o número e o texto; sem número, só o texto', () {
    final com = uriDoWhatsApp(telefone: '11999998888', texto: 'Oi, tudo bem?');
    expect(
      com.toString(),
      'https://wa.me/5511999998888?text=Oi%2C+tudo+bem%3F',
    );

    final sem = uriDoWhatsApp(texto: 'Oi');
    expect(sem.toString(), 'https://wa.me/?text=Oi');

    expect(
      uriDoWhatsApp(telefone: '11999998888').toString(),
      'https://wa.me/5511999998888',
    );
  });
}
