import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/session/sessao_provider.dart';
import 'package:managers/features/auth/auth_provider.dart';

import 'presentation/providers/home_provider.dart';

// injeção da home. provisória: a home de verdade, com a navegação
// inferior, entra na fase 1 e reaproveita este arquivo
final homeProvider = Provider.autoDispose<HomeProvider>((ref) {
  final provider = HomeProvider(
    logout: ref.watch(logoutUseCaseProvider),
    sessao: ref.watch(sessaoControllerProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});
