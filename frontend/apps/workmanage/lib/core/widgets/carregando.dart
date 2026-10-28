import 'package:flutter/material.dart';

import 'work_manage_loader.dart';

// o estado "carregando" de uma tela inteira: o símbolo animado, centralizado,
// colorido no tema claro e branco no escuro. para um botão ou um campo, use o
// CircularProgressIndicator pequeno
class Carregando extends StatelessWidget {
  const Carregando({super.key});

  @override
  Widget build(BuildContext context) {
    // sem const: o assert da pausa do loader não é avaliado em constante
    return Center(child: WorkManageLoader(size: 72));
  }
}
