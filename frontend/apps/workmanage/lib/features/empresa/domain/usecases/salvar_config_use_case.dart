import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/empresa_config.dart';
import '../repositories/empresa_repository.dart';

class SalvarConfigUseCase implements UseCase<EmpresaConfig, EmpresaConfig> {
  const SalvarConfigUseCase(this._repository);

  final EmpresaRepository _repository;

  @override
  Future<Either<Failure, EmpresaConfig>> call(EmpresaConfig params) {
    return _repository.salvarConfig(params);
  }
}
