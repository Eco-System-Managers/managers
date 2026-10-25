import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/servico.dart';
import '../params/alterar_ativo_params.dart';
import '../repositories/servicos_repository.dart';

// inativar tira o serviço da vitrine na hora; reativar o traz de volta
class AlterarAtivoServicoUseCase
    implements UseCase<Servico, AlterarAtivoParams> {
  const AlterarAtivoServicoUseCase(this._repository);

  final ServicosRepository _repository;

  @override
  Future<Either<Failure, Servico>> call(AlterarAtivoParams params) {
    return _repository.alterarAtivo(params.id, params.ativo);
  }
}
