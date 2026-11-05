import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repositories/novidades_repository_impl.dart';
import 'domain/repositories/novidades_repository.dart';
import 'domain/usecases/buscar_novidades_use_case.dart';
import 'domain/usecases/marcar_novidades_vistas_use_case.dart';
import 'presentation/providers/novidades_provider.dart';

// injeção das novidades: o único lugar que conhece a implementação do
// repository
final novidadesRepositoryProvider = Provider<NovidadesRepository>(
  (ref) => NovidadesRepositoryImpl(),
);

final buscarNovidadesUseCaseProvider = Provider<BuscarNovidadesUseCase>(
  (ref) => BuscarNovidadesUseCase(ref.watch(novidadesRepositoryProvider)),
);

final marcarNovidadesVistasUseCaseProvider =
    Provider<MarcarNovidadesVistasUseCase>(
      (ref) =>
          MarcarNovidadesVistasUseCase(ref.watch(novidadesRepositoryProvider)),
    );

// vive com a casca, que o observa
final novidadesProvider = Provider.autoDispose<NovidadesProvider>((ref) {
  final provider = NovidadesProvider(
    buscar: ref.watch(buscarNovidadesUseCaseProvider),
    marcarVistas: ref.watch(marcarNovidadesVistasUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});
