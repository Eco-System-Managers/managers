import 'package:flutter/material.dart';

// a "sombra branca" encostada na barra inferior: a cor do fundo da tela
// entrando por cima do conteúdo, espalhada numa faixa alta e bem suave, para
// o que rola não cortar seco contra a barra. não pega toque. cada aba põe a
// sombra no próprio corpo (comSombraEmBaixo), e não a casca: assim o botão
// flutuante da aba, que o Scaffold desenha por cima do corpo, fica acima dela
class SombraDeBorda extends StatelessWidget {
  const SombraDeBorda({super.key, this.altura = 56});

  final double altura;

  @override
  Widget build(BuildContext context) {
    final fundo = Theme.of(context).scaffoldBackgroundColor;
    return IgnorePointer(
      child: SizedBox(
        height: altura,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              // uma curva suave (ease) em vez de degraus: sem a borda reta
              // que um degradê linear deixa visível na quebra
              colors: [
                for (var i = 0; i <= 10; i++)
                  fundo.withValues(
                    alpha: 0.95 * (1 - Curves.easeInOutSine.transform(i / 10)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// o corpo de uma aba com a sombra encostada na borda de baixo
Widget comSombraEmBaixo(Widget corpo) {
  return Stack(
    children: [
      corpo,
      const Positioned(left: 0, right: 0, bottom: 0, child: SombraDeBorda()),
    ],
  );
}
