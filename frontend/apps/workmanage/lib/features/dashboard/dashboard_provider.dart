import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/network/dio_client.dart';
import 'package:managers/features/agenda/agenda_provider.dart'
    show listarPendenciasUseCaseProvider;
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:managers/features/usuarios/usuarios_provider.dart';

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

// autoDispose: a aba vive dentro da casca, então o período escolhido dura
// enquanto a sessão durar e é zerado quando outra pessoa entra
final resumoProvider = Provider.autoDispose<ResumoProvider>((ref) {
  final provider = ResumoProvider(
    obterResumo: ref.watch(obterResumoUseCaseProvider),
    listarColaboradores: ref.watch(listarColaboradoresUseCaseProvider),
    listarPendencias: ref.watch(listarPendenciasUseCaseProvider),
    // a casca só monta as abas com o negócio (e o papel) carregados
    filtraPorProfissional: ref.watch(negocioAtualProvider).ehProprietario,
  );
  ref.onDispose(provider.dispose);
  return provider;
});
