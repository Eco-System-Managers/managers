import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../repositories/auth_repository.dart';

// envia (ou reenvia) o código de recuperação para o e-mail
class SendRecoveryCodeUseCase implements UseCase<void, String> {
  const SendRecoveryCodeUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, void>> call(String params) {
    return _repository.sendRecoveryCode(params);
  }
}
