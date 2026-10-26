import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/dashboard_resumo.dart';
import '../repositories/dashboard_repository.dart';

class ResumoParams {
  const ResumoParams({this.inicio, this.fim, this.colaboradorId});

  final DateTime? inicio;
  final DateTime? fim;
  final int? colaboradorId;
}

class ObterResumoUseCase implements UseCase<DashboardResumo, ResumoParams> {
  const ObterResumoUseCase(this._repository);

  final DashboardRepository _repository;

  @override
  Future<Either<Failure, DashboardResumo>> call(ResumoParams params) =>
      _repository.resumo(
        inicio: params.inicio,
        fim: params.fim,
        colaboradorId: params.colaboradorId,
      );
}
