import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/novidade.dart';
import '../repositories/novidades_repository.dart';

class BuscarNovidadesParams {
  const BuscarNovidadesParams({required this.isKanban});

  final bool isKanban;
}

// as novidades desta versão que valem para o negócio, ou nenhuma se o
// aparelho já as mostrou. o armazenamento falhando também é nenhuma: é
// melhor não mostrar do que mostrar a cada abertura
class BuscarNovidadesUseCase
    implements UseCase<List<Novidade>, BuscarNovidadesParams> {
  BuscarNovidadesUseCase(this._repository);

  final NovidadesRepository _repository;

  @override
  Future<Either<Failure, List<Novidade>>> call(
    BuscarNovidadesParams params,
  ) async {
    try {
      if (await _repository.ultimaVista() == versaoDasNovidades) {
        return const Right([]);
      }
    } catch (_) {
      return const Right([]);
    }
    return Right([
      for (final n in novidadesDaVersao)
        if (n.valePara(isKanban: params.isKanban)) n,
    ]);
  }
}
