import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/cliente.dart';
import '../repositories/clientes_repository.dart';

class AtualizarClienteUseCase implements UseCase<Cliente, Cliente> {
  const AtualizarClienteUseCase(this._repository);

  final ClientesRepository _repository;

  @override
  Future<Either<Failure, Cliente>> call(Cliente params) {
    return _repository.atualizar(params);
  }
}
