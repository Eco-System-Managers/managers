import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/brand.dart';

// as três formas do logo (design/07-assets): o horizontal é o uso padrão; o
// empilhado vai em espaço quadrado (splash, abertura); o símbolo, sozinho
enum FormaDoLogo { horizontal, empilhado, simbolo }

// as versões de cor que o app usa. a versão azul (carimbo, bordado) fica fora
enum CorDoLogo { colorido, branco, marinho }

// o logo do Work Manage nas versões do Design System, com a wordmark já em
// curvas. sem [cor], escolhe pelo [fundo] (ou pelo fundo do tema): colorido
// sobre bg e bg-2; branco sobre o marinho, o azul ou o fundo escuro; marinho
// sobre outro fundo claro. guarda o respiro de 1/4 da altura do símbolo em
// volta e o tamanho mínimo: abaixo de 24 px de altura o logo vira só o
// símbolo, que não desce de 16 px
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    required this.altura,
    this.forma = FormaDoLogo.horizontal,
    this.cor,
    this.fundo,
    this.respiro = true,
  });

  // a altura do desenho, sem o respiro
  final double altura;
  final FormaDoLogo forma;
  final CorDoLogo? cor;
  final Color? fundo;

  // false quando quem usa já dá o espaço em volta (ex.: a AppBar)
  final bool respiro;

  static const alturaMinimaDoLogo = 24.0;
  static const alturaMinimaDoSimbolo = 16.0;

  // largura / altura de cada desenho (o viewBox dos SVGs)
  static const _proporcao = {
    FormaDoLogo.horizontal: 1019.42 / 120,
    FormaDoLogo.empilhado: 190 / 169.33,
    FormaDoLogo.simbolo: 188.11 / 120,
  };

  // a parte da altura do desenho que é o símbolo: o respiro é 1/4 dela
  static const _alturaDoSimbolo = {
    FormaDoLogo.horizontal: 1.0,
    FormaDoLogo.empilhado: 120 / 169.33,
    FormaDoLogo.simbolo: 1.0,
  };

  static const _arquivos = {
    FormaDoLogo.horizontal: 'w-logo',
    FormaDoLogo.empilhado: 'w-logo-stacked',
    FormaDoLogo.simbolo: 'w-mark',
  };

  // a versão certa para um fundo
  static CorDoLogo corPeloFundo(Color fundo) {
    final opaco = fundo.withValues(alpha: 1);
    if (opaco.computeLuminance() < 0.5) return CorDoLogo.branco;
    const fundosDaPaleta = [BrandColors.light, BrandColors.dark];
    for (final c in fundosDaPaleta) {
      if (opaco == c.bg || opaco == c.bg2) return CorDoLogo.colorido;
    }
    return CorDoLogo.marinho;
  }

  // a forma e a altura que de fato aparecem, já com o tamanho mínimo
  static (FormaDoLogo, double) _medida(FormaDoLogo forma, double altura) {
    if (forma != FormaDoLogo.simbolo && altura < alturaMinimaDoLogo) {
      forma = FormaDoLogo.simbolo;
    }
    if (forma == FormaDoLogo.simbolo && altura < alturaMinimaDoSimbolo) {
      altura = alturaMinimaDoSimbolo;
    }
    return (forma, altura);
  }

  // a maior altura de desenho que cabe na [area], já contando o respiro
  static double alturaQueCabe(
    FormaDoLogo forma,
    BoxConstraints area, {
    bool respiro = true,
  }) {
    final folga = respiro ? _alturaDoSimbolo[forma]! / 2 : 0.0;
    return math.min(
      area.maxHeight / (1 + folga),
      area.maxWidth / (_proporcao[forma]! + folga),
    );
  }

  static String arquivo(FormaDoLogo forma, CorDoLogo cor) {
    final sufixo = switch (cor) {
      CorDoLogo.colorido => '',
      CorDoLogo.branco => '-white',
      CorDoLogo.marinho => '-navy',
    };
    return 'assets/brand/${_arquivos[forma]}$sufixo.svg';
  }

  @override
  Widget build(BuildContext context) {
    final (formaFinal, alturaFinal) = _medida(forma, altura);
    final corFinal =
        cor ?? corPeloFundo(fundo ?? Theme.of(context).scaffoldBackgroundColor);
    final folga = respiro
        ? alturaFinal * _alturaDoSimbolo[formaFinal]! / 4
        : 0.0;

    return Padding(
      padding: EdgeInsets.all(folga),
      child: SvgPicture.asset(
        arquivo(formaFinal, corFinal),
        height: alturaFinal,
        width: alturaFinal * _proporcao[formaFinal]!,
        fit: BoxFit.contain,
        semanticsLabel: 'Work Manage',
      ),
    );
  }
}
