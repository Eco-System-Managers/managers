import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../params/verify_recovery_code_params.dart';
import '../repositories/auth_repository.dart';

class VerifyRecoveryCodeUseCase
    implements UseCase<void, VerifyRecoveryCodeParams> {
  const VerifyRecoveryCodeUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, void>> call(VerifyRecoveryCodeParams params) {
    return _repository.verifyRecoveryCode(params.email, params.codigo);
  }
}
