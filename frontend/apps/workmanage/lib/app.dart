import 'package:flutter/material.dart';
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
        brightness == Brightness.light ? theme.light() : theme.dark(),
      ),
      routerConfig: ref.watch(routerProvider),
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
ThemeData _comAjustes(ThemeData base) {
  final colors = base.colorScheme;
  return base.copyWith(
    // o seletor de intervalo pinta os dias entre as pontas com
    // primaryContainer, que neste tema é azul-escuro: com o texto escuro do
    // modo claro a faixa ficava preta. a cor fixa clara mantém o texto legível
    datePickerTheme: DatePickerThemeData(
      rangeSelectionBackgroundColor: colors.brightness == Brightness.light
          ? colors.primaryFixed
          : colors.primaryContainer,
    ),
  );
}
