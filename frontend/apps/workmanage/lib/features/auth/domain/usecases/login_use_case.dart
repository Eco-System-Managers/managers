import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../params/login_params.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase implements UseCase<Sessao, LoginParams> {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, Sessao>> call(LoginParams params) {
    return _repository.login(params.email, params.senha);
  }
}
