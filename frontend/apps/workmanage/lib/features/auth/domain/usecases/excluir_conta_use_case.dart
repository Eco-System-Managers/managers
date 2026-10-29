import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../repositories/auth_repository.dart';

// recebe a senha de quem pede: confirma que é a própria pessoa
class ExcluirContaUseCase implements UseCase<void, String> {
  const ExcluirContaUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, void>> call(String params) {
    return _repository.excluirConta(params);
  }
}
