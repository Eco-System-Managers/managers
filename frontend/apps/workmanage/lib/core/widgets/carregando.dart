import 'package:flutter/material.dart';

import 'work_manage_loader.dart';

// o estado "carregando" de uma tela inteira: o logo animado, centralizado.
// para um botão ou um campo, use o CircularProgressIndicator pequeno
class Carregando extends StatelessWidget {
  const Carregando({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: WorkManageLoader(
        size: 72,
        color: dark ? Colors.white : WorkManageLoader.brandBlue,
      ),
    );
  }
}
