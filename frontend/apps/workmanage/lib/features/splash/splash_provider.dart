import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/session/sessao_provider.dart';
import 'package:managers/features/onboarding/onboarding_provider.dart';

import 'presentation/providers/splash_provider.dart';

// injeção da splash. a decisão da rota inicial precisa da sessão e da
// config da empresa (onboarding concluído ou não), que vem do use case do
// onboarding. autoDispose: a splash abre, decide e some
final splashProvider = Provider.autoDispose<SplashProvider>((ref) {
  final provider = SplashProvider(
    sessao: ref.watch(sessaoControllerProvider),
    buscarConfig: ref.watch(buscarConfigUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});
