import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/horario_funcionamento.dart';
import '../repositories/empresa_repository.dart';

class BuscarHorariosUseCase
    implements UseCase<List<HorarioFuncionamento>, NoParams> {
  const BuscarHorariosUseCase(this._repository);

  final EmpresaRepository _repository;

  @override
  Future<Either<Failure, List<HorarioFuncionamento>>> call(NoParams params) {
    return _repository.buscarHorarios();
  }
}
