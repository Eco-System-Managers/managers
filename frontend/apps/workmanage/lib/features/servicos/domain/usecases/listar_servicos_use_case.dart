import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/servico.dart';
import '../params/listar_servicos_params.dart';
import '../repositories/servicos_repository.dart';

class ListarServicosUseCase
    implements UseCase<List<Servico>, ListarServicosParams> {
  const ListarServicosUseCase(this._repository);

  final ServicosRepository _repository;

  @override
  Future<Either<Failure, List<Servico>>> call(ListarServicosParams params) {
    return _repository.listar(busca: params.busca, ativo: params.ativo);
  }
}
