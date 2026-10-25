import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/servico.dart';
import '../repositories/servicos_repository.dart';

class ObterServicoUseCase implements UseCase<Servico, int> {
  const ObterServicoUseCase(this._repository);

  final ServicosRepository _repository;

  @override
  Future<Either<Failure, Servico>> call(int params) {
    return _repository.obter(params);
  }
}
