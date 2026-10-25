import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/servico.dart';
import '../repositories/servicos_repository.dart';

class AtualizarServicoUseCase implements UseCase<Servico, Servico> {
  const AtualizarServicoUseCase(this._repository);

  final ServicosRepository _repository;

  @override
  Future<Either<Failure, Servico>> call(Servico params) {
    return _repository.atualizar(params);
  }
}
