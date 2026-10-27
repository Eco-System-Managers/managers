import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/routing/app_router.dart';

import 'core/utils/util.dart';
import 'core/theme/theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = View.of(context).platformDispatcher.platformBrightness;

    TextTheme textTheme = createTextTheme(context, "Roboto", "DM Sans");
    MaterialTheme theme = MaterialTheme(textTheme);

    return MaterialApp.router(
      title: 'Work Manage',
      theme: _comAjustes(
        theme,
        brightness == Brightness.light
            ? MaterialTheme.lightScheme()
            : MaterialTheme.darkScheme(),
      ),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => _AcimaDaBarraDoSistema(child: child!),
      // tudo em português: os textos dos widgets do Flutter (relógio,
      // calendário, botões de diálogo) e os formatos de data
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}

// o que o tema gerado (core/theme/theme.dart) não cobre bem. ele não é
// editado à mão: é saído do Material Theme Builder
ThemeData _comAjustes(MaterialTheme tema, ColorScheme gerado) {
  final claro = gerado.brightness == Brightness.light;

  // a cor secundária do tema gerado é preto puro, e o Material 3 deriva dela
  // o par secondaryContainer/onSecondaryContainer, usado em tudo que é
  // "selecionado" (chip, botão segmentado, botão tonal) e nas caixas de
  // aviso: no claro saía preto com letra cinza, no escuro cinza sobre cinza.
  // o par passa a ser um azul derivado da primária
  final colors = gerado.copyWith(
    secondaryContainer: claro
        ? gerado.primaryFixed
        : gerado.onPrimaryFixedVariant,
    onSecondaryContainer: claro
        ? gerado.onPrimaryFixedVariant
        : gerado.primaryFixed,
  );

  return tema
      .theme(colors)
      .copyWith(
        // o seletor de intervalo pinta os dias entre as pontas com
        // primaryContainer, que neste tema é azul-escuro: com o texto escuro do
        // modo claro a faixa ficava preta. a cor fixa clara mantém o texto legível
        datePickerTheme: DatePickerThemeData(
          rangeSelectionBackgroundColor: claro
              ? colors.primaryFixed
              : colors.primaryContainer,
        ),
      );
}

// o app inteiro termina acima da barra de navegação do Android (os três
// botões ou a alça de gestos): nada rola por baixo dela, em tela nenhuma. a
// barra do sistema é transparente, então o que aparece embaixo dela é o
// fundo do app, com os ícones dela na cor do tema. o teclado continua
// chegando pelo viewInsets, que não é tocado aqui
class _AcimaDaBarraDoSistema extends StatelessWidget {
  const _AcimaDaBarraDoSistema({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final claro = tema.brightness == Brightness.light;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: claro
            ? Brightness.dark
            : Brightness.light,
      ),
      child: ColoredBox(
        color: tema.scaffoldBackgroundColor,
        child: SafeArea(top: false, left: false, right: false, child: child),
      ),
    );
  }
}
