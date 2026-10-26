import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // de ponta a ponta em todo Android, não só no 15+: o app desenha por baixo
  // das barras do sistema e cada tela cuida da área segura (Scaffold, barra
  // inferior, abrirFolha e paddingDaPagina). assim o comportamento é um só
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  // ProviderScope guarda os providers (injeção de dependências)
  runApp(const ProviderScope(child: App()));
}
