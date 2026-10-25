import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../repositories/clientes_repository.dart';

// cliente manual é apagado; o que veio do app é arquivado e desvinculado
class RemoverClienteUseCase implements UseCase<void, int> {
  const RemoverClienteUseCase(this._repository);

  final ClientesRepository _repository;

  @override
  Future<Either<Failure, void>> call(int params) {
    return _repository.remover(params);
  }
}
