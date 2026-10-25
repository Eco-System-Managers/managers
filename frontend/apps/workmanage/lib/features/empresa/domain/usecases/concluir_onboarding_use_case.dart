import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/empresa_config.dart';
import '../repositories/onboarding_repository.dart';

class ConcluirOnboardingUseCase implements UseCase<EmpresaConfig, NoParams> {
  const ConcluirOnboardingUseCase(this._repository);

  final OnboardingRepository _repository;

  @override
  Future<Either<Failure, EmpresaConfig>> call(NoParams params) {
    return _repository.concluir();
  }
}
