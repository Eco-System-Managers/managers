import 'package:flutter/material.dart';

import 'sombra_de_borda.dart';

// o botão principal de uma tela fixo no rodapé, no desenho da barra
// inferior das abas: uma pílula solta, com margem, que não rola junto com o
// conteúdo. vai no bottomNavigationBar do Scaffold; o corpo da tela recebe
// a sombra branca encostada nele por comSombraEmBaixo
class BotaoDeRodape extends StatelessWidget {
  const BotaoDeRodape({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icone,
  });

  final String texto;

  // null desabilita (carregando)
  final VoidCallback? onPressed;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final estilo = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: icone == null
          ? FilledButton(
              onPressed: onPressed,
              style: estilo,
              child: Text(texto),
            )
          : FilledButton.icon(
              onPressed: onPressed,
              style: estilo,
              icon: Icon(icone),
              label: Text(texto),
            ),
    );
  }
}

// o corpo de uma tela com BotaoDeRodape: a sombra encostada no botão
Widget comBotaoDeRodape(Widget corpo) => comSombraEmBaixo(corpo);
