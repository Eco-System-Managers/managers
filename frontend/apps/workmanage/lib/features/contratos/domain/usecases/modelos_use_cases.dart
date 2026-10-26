import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/modelo_contrato.dart';
import '../repositories/contratos_repository.dart';

class ListarModelosParams {
  const ListarModelosParams({this.ativo});

  final bool? ativo;
}

class ListarModelosUseCase
    implements UseCase<List<ModeloContrato>, ListarModelosParams> {
  const ListarModelosUseCase(this._repository);

  final ContratosRepository _repository;

  @override
  Future<Either<Failure, List<ModeloContrato>>> call(
    ListarModelosParams params,
  ) => _repository.listarModelos(ativo: params.ativo);
}

class ObterModeloUseCase implements UseCase<ModeloContrato, int> {
  const ObterModeloUseCase(this._repository);

  final ContratosRepository _repository;

  @override
  Future<Either<Failure, ModeloContrato>> call(int id) =>
      _repository.obterModelo(id);
}

class CriarModeloUseCase implements UseCase<ModeloContrato, ModeloContrato> {
  const CriarModeloUseCase(this._repository);

  final ContratosRepository _repository;

  @override
  Future<Either<Failure, ModeloContrato>> call(ModeloContrato modelo) =>
      _repository.criarModelo(modelo);
}

class AtualizarModeloUseCase
    implements UseCase<ModeloContrato, ModeloContrato> {
  const AtualizarModeloUseCase(this._repository);

  final ContratosRepository _repository;

  @override
  Future<Either<Failure, ModeloContrato>> call(ModeloContrato modelo) =>
      _repository.atualizarModelo(modelo);
}

class AlterarAtivoModeloParams {
  const AlterarAtivoModeloParams({required this.id, required this.ativo});

  final int id;
  final bool ativo;
}

class AlterarAtivoModeloUseCase
    implements UseCase<ModeloContrato, AlterarAtivoModeloParams> {
  const AlterarAtivoModeloUseCase(this._repository);

  final ContratosRepository _repository;

  @override
  Future<Either<Failure, ModeloContrato>> call(
    AlterarAtivoModeloParams params,
  ) => _repository.alterarAtivoModelo(params.id, params.ativo);
}
