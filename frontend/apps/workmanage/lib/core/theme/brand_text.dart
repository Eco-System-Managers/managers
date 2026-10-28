import 'package:flutter/material.dart';

import 'brand_colors.dart';

// a tipografia do Design System (tokens.json → type.groups). Inter é a
// interface inteira; MuseoModerno é só a wordmark e o título de capa, nunca
// texto corrido. os estilos não têm cor: a cor vem do tema (textTheme) ou de
// quem usa. na tela, prefira Theme.of(context).textTheme; os estilos daqui
// servem para o que o textTheme não tem (bodyStrong, caption)
abstract final class BrandText {
  static const sans = 'Inter';
  static const brand = 'MuseoModerno';

  // marca (MuseoModerno)

  // a wordmark dos logotipos: só o nome do produto ao lado do símbolo
  static const wordmark = TextStyle(
    fontFamily: brand,
    fontSize: 40,
    height: 44 / 40,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  // título de capa e de abertura
  static const display = TextStyle(
    fontFamily: brand,
    fontSize: 56,
    height: 60 / 56,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.12,
  );

  // títulos (Inter)

  // título de página
  static const h1 = TextStyle(
    fontFamily: sans,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.64,
  );

  // título de seção
  static const h2 = TextStyle(
    fontFamily: sans,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.24,
  );

  // título de cartão e de diálogo
  static const h3 = TextStyle(
    fontFamily: sans,
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  // texto (Inter)

  // texto corrido da interface
  static const body = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  // ênfase dentro do texto, nome em listas
  static const bodyStrong = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  // rótulo de campo, botão pequeno, aba
  static const label = TextStyle(
    fontFamily: sans,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.13,
  );

  // nota e metadado, sempre em inkMuted
  static const caption = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  // os 15 papéis do Material 3 encaixados nos 7 tamanhos de interface do
  // Design System: display e headline em 700, title em 600, body em 400 e
  // label em 500. a legenda (bodySmall) já sai em inkMuted
  static TextTheme textTheme(BrandColors cores) {
    TextStyle inter(TextStyle medida, FontWeight peso, [Color? cor]) {
      return TextStyle(
        fontFamily: sans,
        fontSize: medida.fontSize,
        height: medida.height,
        letterSpacing: medida.letterSpacing,
        fontWeight: peso,
        color: cor ?? cores.ink,
      );
    }

    return TextTheme(
      displayLarge: inter(display, FontWeight.w700),
      displayMedium: inter(wordmark, FontWeight.w700),
      displaySmall: inter(h1, FontWeight.w700),
      headlineLarge: inter(h1, FontWeight.w700),
      headlineMedium: inter(h2, FontWeight.w700),
      headlineSmall: inter(h2, FontWeight.w700),
      titleLarge: inter(h3, FontWeight.w600),
      titleMedium: inter(bodyStrong, FontWeight.w600),
      titleSmall: inter(label, FontWeight.w600),
      bodyLarge: inter(body, FontWeight.w400),
      bodyMedium: inter(body, FontWeight.w400),
      bodySmall: inter(caption, FontWeight.w400, cores.inkMuted),
      labelLarge: inter(label, FontWeight.w500),
      labelMedium: inter(caption, FontWeight.w500),
      labelSmall: inter(caption, FontWeight.w500),
    );
  }
}
