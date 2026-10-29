import 'package:flutter/material.dart';

import '../theme/brand.dart';
import 'sombra_de_borda.dart';

// o botão principal de uma tela fixo no rodapé, no desenho da barra
// inferior das abas: solto, com margem, sem rolar junto com o conteúdo. a
// forma e o texto vêm do tema (radius-md, body-strong). vai no
// bottomNavigationBar do Scaffold; o corpo da tela recebe a sombra branca
// encostada nele por comBotaoDeRodape
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
    // a altura é medida do componente, não espaçamento
    final estilo = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BrandSpacing.space4,
        0,
        BrandSpacing.space4,
        BrandSpacing.space3,
      ),
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
