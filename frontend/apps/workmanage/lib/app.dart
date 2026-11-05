import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/routing/app_router.dart';

import 'core/tema/preferencia_de_tema.dart';
import 'core/tema/tema_provider.dart';
import 'core/theme/theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = ref.watch(temaControllerProvider);
    final router = ref.watch(routerProvider);

    return ListenableBuilder(
      listenable: tema,
      builder: (context, _) => MaterialApp.router(
        title: 'Work Manage',
        // o tema do Design System: o claro ou o escuro escolhido no Mais,
        // ou o do aparelho
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _modo(tema.preferencia),
        routerConfig: router,
        builder: (context, child) => _AcimaDaBarraDoSistema(child: child!),
        // tudo em português: os textos dos widgets do Flutter (relógio,
        // calendário, botões de diálogo) e os formatos de data
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    );
  }

  static ThemeMode _modo(PreferenciaDeTema preferencia) {
    return switch (preferencia) {
      PreferenciaDeTema.sistema => ThemeMode.system,
      PreferenciaDeTema.claro => ThemeMode.light,
      PreferenciaDeTema.escuro => ThemeMode.dark,
    };
  }
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
