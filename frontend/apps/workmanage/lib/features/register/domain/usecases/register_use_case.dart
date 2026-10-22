import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../params/register_param.dart';
import '../repositories/register_repository.dart';

// tipo de retorno e tipo de parametro
class RegisterUseCase implements UseCase<void, RegisterParam> {
  const RegisterUseCase(this._repository);

  final RegisterRepository _repository;

  @override
  Future<Either<Failure, void>> call(RegisterParam params) async {
    return await _repository.register(params);
  }
}
