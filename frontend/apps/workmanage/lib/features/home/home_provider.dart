import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/session/sessao_provider.dart';
import 'package:managers/features/auth/auth_provider.dart';

import 'presentation/providers/mais_provider.dart';

// injeção da home. a casca lê o negócio atual direto da empresa; aqui fica
// só o estado da aba "Mais". autoDispose: ao sair da aba ele é descartado
final maisProvider = Provider.autoDispose<MaisProvider>((ref) {
  final provider = MaisProvider(
    logout: ref.watch(logoutUseCaseProvider),
    sessao: ref.watch(sessaoControllerProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});
