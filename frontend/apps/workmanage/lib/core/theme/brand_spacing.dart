import 'package:flutter/painting.dart';

// a escala de espaçamento do Design System (tokens.json → spacing), base 4.
// valor fora da escala vira o token mais próximo; no empate, o menor
abstract final class BrandSpacing {
  // entre ícone e texto; dentro de badges
  static const double space1 = 4;

  // entre rótulo e campo; itens de lista compacta
  static const double space2 = 8;

  // padding interno de botões e campos
  static const double space3 = 12;

  // padding de cartões; vão entre cartões
  static const double space4 = 16;

  // padding de seções; respiro mínimo em volta do logo
  static const double space5 = 24;

  // entre blocos de página
  static const double space6 = 40;

  // margens de capa
  static const double space7 = 64;
}

// os raios do Design System (tokens.json → radius)
abstract final class BrandRadius {
  // campos, badges e chips
  static const double sm = 6;

  // botões e cartões: o raio dos cantos dos símbolos (≈ 1/10 da altura)
  static const double md = 12;

  // painéis grandes, folhas e diálogos
  static const double lg = 20;

  // ícone do app: 22 % do lado do quadrado
  static const double icon = 0.22;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));

  // o topo arredondado das folhas de baixo e dos painéis encostados embaixo
  static const lgTop = BorderRadius.vertical(top: Radius.circular(lg));
}
