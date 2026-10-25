import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/servico.dart';
import '../repositories/servicos_repository.dart';

// devolve o serviço como a API gravou, com o id
class CriarServicoUseCase implements UseCase<Servico, Servico> {
  const CriarServicoUseCase(this._repository);

  final ServicosRepository _repository;

  @override
  Future<Either<Failure, Servico>> call(Servico params) {
    return _repository.criar(params);
  }
}
