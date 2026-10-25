import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/colaborador.dart';
import '../repositories/usuarios_repository.dart';

// a equipe inteira, para escolher quem executa um serviço
class ListarColaboradoresUseCase
    implements UseCase<List<Colaborador>, NoParams> {
  const ListarColaboradoresUseCase(this._repository);

  final UsuariosRepository _repository;

  @override
  Future<Either<Failure, List<Colaborador>>> call(NoParams params) {
    return _repository.listarColaboradores();
  }
}
