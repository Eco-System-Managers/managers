import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call(String email, String password) {
    return _repository.login(email, password);
  }
}
