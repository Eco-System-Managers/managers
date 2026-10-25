import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/dashboard_resumo.dart';
import '../repositories/dashboard_repository.dart';

class ObterResumoUseCase implements UseCase<DashboardResumo, NoParams> {
  const ObterResumoUseCase(this._repository);

  final DashboardRepository _repository;

  @override
  Future<Either<Failure, DashboardResumo>> call(NoParams params) =>
      _repository.resumo();
}
