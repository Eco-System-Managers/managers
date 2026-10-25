import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/features/empresa/empresa_provider.dart';

import 'presentation/providers/wizard_provider.dart';

// injeção do onboarding: a config, os horários e o CEP são da empresa, então
// o wizard usa os use cases de lá. aqui fica só o estado da tela.
// autoDispose: ao sair do onboarding ele é descartado; os dados estão na
// API e voltam no próximo carregar()
final wizardProvider = Provider.autoDispose<WizardProvider>((ref) {
  final wizard = WizardProvider(
    buscarConfig: ref.watch(buscarConfigUseCaseProvider),
    salvarConfig: ref.watch(salvarConfigUseCaseProvider),
    buscarEnderecoPorCep: ref.watch(buscarEnderecoPorCepUseCaseProvider),
    buscarHorarios: ref.watch(buscarHorariosUseCaseProvider),
    salvarHorarios: ref.watch(salvarHorariosUseCaseProvider),
    concluirOnboarding: ref.watch(concluirOnboardingUseCaseProvider),
  );
  ref.onDispose(wizard.dispose);
  return wizard;
});
