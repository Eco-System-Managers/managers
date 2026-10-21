import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  // ProviderScope guarda os providers (injeção de dependências)
  runApp(const ProviderScope(child: App()));
}
