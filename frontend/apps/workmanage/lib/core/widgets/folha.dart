import 'package:flutter/material.dart';

import '../theme/brand.dart';

// abre uma folha de baixo que respeita o teclado e a barra de navegação do
// sistema. com o app de ponta a ponta (edge-to-edge), o Android desenha os
// botões de navegação por cima do app, e o último botão da folha ficava
// embaixo deles: o useSafeArea do Flutter só protege o topo. toda folha do
// app abre por aqui, e o conteúdo dela não precisa cuidar de recuo nenhum
Future<T?> abrirFolha<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(top: false, child: builder(context)),
    ),
  );
}

// o recuo padrão das telas de formulário e ficha que rolam (space-5, o
// padding de seções), com espaço extra embaixo para a barra de navegação do
// sistema: a lista rola por baixo dela, mas o último botão para acima. nas
// abas (que têm a barra inferior do app) o extra é zero
EdgeInsets paddingDaPagina(
  BuildContext context, {
  double topo = BrandSpacing.space5,
}) {
  return EdgeInsets.fromLTRB(
    BrandSpacing.space5,
    topo,
    BrandSpacing.space5,
    BrandSpacing.space5 + MediaQuery.paddingOf(context).bottom,
  );
}
