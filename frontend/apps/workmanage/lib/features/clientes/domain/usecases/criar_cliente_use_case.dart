import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/cliente.dart';
import '../repositories/clientes_repository.dart';

// devolve o cliente como a API gravou, com o id
class CriarClienteUseCase implements UseCase<Cliente, Cliente> {
  const CriarClienteUseCase(this._repository);

  final ClientesRepository _repository;

  @override
  Future<Either<Failure, Cliente>> call(Cliente params) {
    return _repository.criar(params);
  }
}
