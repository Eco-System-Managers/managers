import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/colaborador.dart';
import '../repositories/usuarios_repository.dart';

class BuscarMeuPerfilUseCase implements UseCase<Colaborador, NoParams> {
  const BuscarMeuPerfilUseCase(this._repository);

  final UsuariosRepository _repository;

  @override
  Future<Either<Failure, Colaborador>> call(NoParams params) {
    return _repository.buscarMeuPerfil();
  }
}
