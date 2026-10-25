import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/network/dio_client.dart';

import 'data/datasources/dashboard_remote_datasource.dart';
import 'data/repositories/dashboard_repository_impl.dart';
import 'domain/repositories/dashboard_repository.dart';
import 'domain/usecases/obter_resumo_use_case.dart';
import 'presentation/providers/resumo_provider.dart';

// injeção de dependências do painel: é o único lugar que conhece as
// implementações
final dashboardRemoteDataSourceProvider = Provider<DashboardRemoteDataSource>(
  (ref) => DashboardRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) =>
      DashboardRepositoryImpl(ref.watch(dashboardRemoteDataSourceProvider)),
);

final obterResumoUseCaseProvider = Provider(
  (ref) => ObterResumoUseCase(ref.watch(dashboardRepositoryProvider)),
);

// autoDispose: o resumo é recarregado a cada abertura
final resumoProvider = Provider.autoDispose<ResumoProvider>((ref) {
  final provider = ResumoProvider(
    obterResumo: ref.watch(obterResumoUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});
