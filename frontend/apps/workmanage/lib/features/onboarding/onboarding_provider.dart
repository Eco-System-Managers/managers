import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/datasources/onboarding_fake_datasource.dart';
import 'data/datasources/onboarding_remote_datasource.dart';
import 'data/repositories/onboarding_repository_impl.dart';
import 'domain/repositories/onboarding_repository.dart';
import 'domain/usecases/buscar_config_use_case.dart';
import 'domain/usecases/buscar_endereco_por_cep_use_case.dart';
import 'domain/usecases/buscar_horarios_use_case.dart';
import 'domain/usecases/concluir_onboarding_use_case.dart';
import 'domain/usecases/salvar_config_use_case.dart';
import 'domain/usecases/salvar_horarios_use_case.dart';

// injeção de dependências do onboarding: é o único lugar que conhece as
// implementações. trocar a simulação pela API é mexer só no primeiro provider

// sem autoDispose: o fake guarda os dados em memória, e precisa ser a mesma
// instância enquanto o app estiver aberto
final onboardingRemoteDataSourceProvider = Provider<OnboardingRemoteDataSource>(
  (ref) => OnboardingFakeDataSource(),
);

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) =>
      OnboardingRepositoryImpl(ref.watch(onboardingRemoteDataSourceProvider)),
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
