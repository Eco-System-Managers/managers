import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/theme/theme.dart';
import 'package:managers/core/widgets/auth_logo.dart';
import 'package:managers/core/widgets/brand_logo.dart';
import 'package:managers/core/widgets/work_manage_loader.dart';

String arquivoDesenhado(WidgetTester tester) {
  final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
  return (svg.bytesLoader as SvgAssetLoader).assetName;
}

Widget comTema(Widget filho, {ThemeData? tema}) {
  return MaterialApp(
    theme: tema ?? AppTheme.light(),
    home: Scaffold(body: Center(child: filho)),
  );
}

void main() {
  group('corPeloFundo', () {
    test('branco sobre o marinho, o azul e o fundo escuro', () {
      for (final fundo in [
        BrandColors.brandNavy,
        BrandColors.brandBlue,
        BrandColors.dark.blue,
        BrandColors.dark.bg,
        BrandColors.dark.bg2,
      ]) {
        expect(BrandLogo.corPeloFundo(fundo), CorDoLogo.branco);
      }
    });

    test('colorido sobre bg e bg-2; marinho sobre outro fundo claro', () {
      expect(BrandLogo.corPeloFundo(BrandColors.light.bg), CorDoLogo.colorido);
      expect(BrandLogo.corPeloFundo(BrandColors.light.bg2), CorDoLogo.colorido);
      expect(
        BrandLogo.corPeloFundo(BrandColors.light.blueSoft),
        CorDoLogo.marinho,
      );
      expect(
        BrandLogo.corPeloFundo(const Color(0xFFFFF4E5)),
        CorDoLogo.marinho,
      );
    });
  });

  group('BrandLogo', () {
    testWidgets('sem cor, segue o fundo do tema', (tester) async {
      await tester.pumpWidget(comTema(const BrandLogo(altura: 32)));
      expect(arquivoDesenhado(tester), 'assets/brand/w-logo.svg');

      await tester.pumpWidget(
        comTema(const BrandLogo(altura: 32), tema: AppTheme.dark()),
      );
      // o MaterialApp anima a troca de tema
      await tester.pumpAndSettle();
      expect(arquivoDesenhado(tester), 'assets/brand/w-logo-white.svg');
    });

    testWidgets('abaixo de 24 px o logo vira só o símbolo', (tester) async {
      await tester.pumpWidget(comTema(const BrandLogo(altura: 20)));
      expect(arquivoDesenhado(tester), 'assets/brand/w-mark.svg');
    });

    testWidgets('o símbolo não desce de 16 px', (tester) async {
      await tester.pumpWidget(
        comTema(
          const BrandLogo(
            forma: FormaDoLogo.simbolo,
            altura: 10,
            respiro: false,
          ),
        ),
      );
      expect(tester.getSize(find.byType(SvgPicture)).height, 16);
    });

    testWidgets('o respiro é 1/4 da altura do símbolo', (tester) async {
      await tester.pumpWidget(
        comTema(const BrandLogo(forma: FormaDoLogo.simbolo, altura: 96)),
      );
      final padding = tester.widget<Padding>(
        find
            .ancestor(
              of: find.byType(SvgPicture),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, const EdgeInsets.all(BrandSpacing.space5));
    });
  });

  group('AuthLogo', () {
    Widget naArea(double altura) =>
        comTema(SizedBox(width: 360, height: altura, child: const AuthLogo()));

    testWidgets('com espaço, o empilhado branco', (tester) async {
      await tester.pumpWidget(naArea(300));
      expect(arquivoDesenhado(tester), 'assets/brand/w-logo-stacked-white.svg');
    });

    testWidgets('com o teclado aberto, só o símbolo', (tester) async {
      await tester.pumpWidget(naArea(60));
      expect(arquivoDesenhado(tester), 'assets/brand/w-mark-white.svg');
    });

    testWidgets('sem espaço nem para o símbolo, some', (tester) async {
      await tester.pumpWidget(naArea(20));
      expect(find.byType(SvgPicture), findsNothing);
    });
  });

  group('WorkManageLoader', () {
    testWidgets('avisa o fim de cada ciclo (a splash espera por ele)', (
      tester,
    ) async {
      var ciclos = 0;
      await tester.pumpWidget(
        comTema(
          WorkManageLoader(
            startFull: true,
            loop: false,
            pauseDuration: const Duration(milliseconds: 1200),
            onCycleEnd: () => ciclos++,
          ),
        ),
      );
      // da pausa até o fim: 1,2 s de pausa e 0,8 s de saída
      await tester.pump(const Duration(milliseconds: 1900));
      expect(ciclos, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(ciclos, 1);
    });

    testWidgets('desenha nos dois temas e com animação reduzida', (
      tester,
    ) async {
      for (final tema in [AppTheme.light(), AppTheme.dark()]) {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: comTema(const Carregamento(), tema: tema),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
      }
    });
  });
}

// o loader de tela inteira, sem const por causa do assert da pausa
class Carregamento extends StatelessWidget {
  const Carregamento({super.key});

  @override
  Widget build(BuildContext context) => WorkManageLoader(size: 72);
}
