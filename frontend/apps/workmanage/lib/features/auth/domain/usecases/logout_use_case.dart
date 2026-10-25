import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../repositories/auth_repository.dart';

// recebe o refresh da sessão atual, que a API revoga
class LogoutUseCase implements UseCase<void, String> {
  const LogoutUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, void>> call(String params) {
    return _repository.logout(params);
  }
}
