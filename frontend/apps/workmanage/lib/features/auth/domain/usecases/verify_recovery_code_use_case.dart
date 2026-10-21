import '../repositories/auth_repository.dart';

class VerifyRecoveryCodeUseCase {
  const VerifyRecoveryCodeUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call(String code) {
    return _repository.verifyRecoveryCode(code);
  }
}
