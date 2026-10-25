import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/lista_paginada.dart';

import '../entities/cliente.dart';
import '../params/listar_clientes_params.dart';
import '../repositories/clientes_repository.dart';

class ListarClientesUseCase
    implements UseCase<ListaPaginada<Cliente>, ListarClientesParams> {
  const ListarClientesUseCase(this._repository);

  final ClientesRepository _repository;

  @override
  Future<Either<Failure, ListaPaginada<Cliente>>> call(
    ListarClientesParams params,
  ) {
    return _repository.listar(pagina: params.pagina, busca: params.busca);
  }
}
