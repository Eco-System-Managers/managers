import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/horario_funcionamento.dart';
import '../repositories/empresa_repository.dart';

class SalvarHorariosUseCase
    implements UseCase<List<HorarioFuncionamento>, List<HorarioFuncionamento>> {
  const SalvarHorariosUseCase(this._repository);

  final EmpresaRepository _repository;

  @override
  Future<Either<Failure, List<HorarioFuncionamento>>> call(
    List<HorarioFuncionamento> params,
  ) {
    return _repository.salvarHorarios(params);
  }
}
