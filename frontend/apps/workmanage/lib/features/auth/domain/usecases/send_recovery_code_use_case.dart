import '../repositories/auth_repository.dart';

// envia (ou reenvia) o código de recuperação para o e-mail
class SendRecoveryCodeUseCase {
  const SendRecoveryCodeUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call(String email) {
    return _repository.sendRecoveryCode(email);
  }
}
