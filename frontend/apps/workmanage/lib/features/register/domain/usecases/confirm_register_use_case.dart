import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../params/confirm_param.dart';
import '../repositories/register_repository.dart';

// confere o código e devolve a sessão da empresa recém-criada
class ConfirmRegisterUseCase implements UseCase<Sessao, ConfirmParam> {
  const ConfirmRegisterUseCase(this._repository);

  final RegisterRepository _repository;

  @override
  Future<Either<Failure, Sessao>> call(ConfirmParam params) async {
    return await _repository.confirm(params);
  }
}
