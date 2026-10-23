import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../params/confirm_param.dart';
import '../repositories/register_repository.dart';

class ConfirmRegisterUseCase implements UseCase<void, ConfirmParam> {
  const ConfirmRegisterUseCase(this._repository);

  final RegisterRepository _repository;

  @override
  Future<Either<Failure, void>> call(ConfirmParam params) async {
    return await _repository.confirm(params);
  }
}
