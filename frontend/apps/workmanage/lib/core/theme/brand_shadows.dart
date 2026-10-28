import 'package:flutter/material.dart';

// a única sombra do Design System (tokens.json → shadow-card): só para o que
// flutua por cima do conteúdo (a barra inferior, um cartão solto, um menu).
// o resto se separa por borda (BrandColors.border)
abstract final class BrandShadows {
  // 0 1px 2px rgba(11,28,53,0.06), 0 4px 12px rgba(11,28,53,0.06)
  static const cardLight = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(11, 28, 53, 0.06),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: Color.fromRGBO(11, 28, 53, 0.06),
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  // 0 1px 2px rgba(0,0,0,0.4), 0 4px 12px rgba(0,0,0,0.3)
  static const cardDark = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.4),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.3),
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  // a sombra do tema atual
  static List<BoxShadow> card(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? cardDark
        : cardLight;
  }
}
