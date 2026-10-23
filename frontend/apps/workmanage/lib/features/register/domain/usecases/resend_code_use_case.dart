import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../repositories/register_repository.dart';

// recebe o e-mail do cadastro pendente
class ResendCodeUseCase implements UseCase<void, String> {
  const ResendCodeUseCase(this._repository);

  final RegisterRepository _repository;

  @override
  Future<Either<Failure, void>> call(String params) async {
    return await _repository.resendCode(params);
  }
}
