import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/cliente.dart';
import '../repositories/clientes_repository.dart';

class ObterClienteUseCase implements UseCase<Cliente, int> {
  const ObterClienteUseCase(this._repository);

  final ClientesRepository _repository;

  @override
  Future<Either<Failure, Cliente>> call(int params) {
    return _repository.obter(params);
  }
}
