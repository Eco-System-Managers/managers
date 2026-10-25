import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/cep/cep_provider.dart';
import 'package:managers/core/network/dio_client.dart';

import 'data/datasources/onboarding_remote_datasource.dart';
import 'data/repositories/onboarding_repository_impl.dart';
import 'domain/repositories/onboarding_repository.dart';
import 'domain/usecases/buscar_config_use_case.dart';
import 'domain/usecases/buscar_endereco_por_cep_use_case.dart';
import 'domain/usecases/buscar_horarios_use_case.dart';
import 'domain/usecases/concluir_onboarding_use_case.dart';
import 'domain/usecases/salvar_config_use_case.dart';
import 'domain/usecases/salvar_horarios_use_case.dart';
import 'presentation/providers/wizard_provider.dart';

// injeção de dependências do onboarding: é o único lugar que conhece as
// implementações. trocar a implementação é mexer só aqui
final onboardingRemoteDataSourceProvider = Provider<OnboardingRemoteDataSource>(
  (ref) => OnboardingRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepositoryImpl(
    ref.watch(onboardingRemoteDataSourceProvider),
    ref.watch(cepDataSourceProvider),
  ),
);

final buscarConfigUseCaseProvider = Provider(
  (ref) => BuscarConfigUseCase(ref.watch(onboardingRepositoryProvider)),
);

final salvarConfigUseCaseProvider = Provider(
  (ref) => SalvarConfigUseCase(ref.watch(onboardingRepositoryProvider)),
);

final buscarEnderecoPorCepUseCaseProvider = Provider(
  (ref) => BuscarEnderecoPorCepUseCase(ref.watch(onboardingRepositoryProvider)),
);

final buscarHorariosUseCaseProvider = Provider(
  (ref) => BuscarHorariosUseCase(ref.watch(onboardingRepositoryProvider)),
);

final salvarHorariosUseCaseProvider = Provider(
  (ref) => SalvarHorariosUseCase(ref.watch(onboardingRepositoryProvider)),
);

final concluirOnboardingUseCaseProvider = Provider(
  (ref) => ConcluirOnboardingUseCase(ref.watch(onboardingRepositoryProvider)),
);

// estado da tela do wizard. autoDispose: ao sair do onboarding ele é
// descartado; os dados estão na API e voltam no próximo carregar()
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
