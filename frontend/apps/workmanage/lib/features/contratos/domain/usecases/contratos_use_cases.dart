import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/contrato.dart';
import '../repositories/contratos_repository.dart';

class ListarContratosParams {
  const ListarContratosParams({this.clienteId, this.status});

  final int? clienteId;
  final StatusContrato? status;
}

class ListarContratosUseCase
    implements UseCase<List<Contrato>, ListarContratosParams> {
  const ListarContratosUseCase(this._repository);

  final ContratosRepository _repository;

  @override
  Future<Either<Failure, List<Contrato>>> call(ListarContratosParams params) =>
      _repository.listarContratos(
        clienteId: params.clienteId,
        status: params.status,
      );
}

class ObterContratoUseCase implements UseCase<Contrato, int> {
  const ObterContratoUseCase(this._repository);

  final ContratosRepository _repository;

  @override
  Future<Either<Failure, Contrato>> call(int id) =>
      _repository.obterContrato(id);
}

class GerarContratoParams {
  const GerarContratoParams({required this.modeloId, required this.clienteId});

  final int modeloId;
  final int clienteId;
}

class GerarContratoUseCase implements UseCase<Contrato, GerarContratoParams> {
  const GerarContratoUseCase(this._repository);

  final ContratosRepository _repository;

  @override
  Future<Either<Failure, Contrato>> call(GerarContratoParams params) =>
      _repository.gerar(modeloId: params.modeloId, clienteId: params.clienteId);
}

class MarcarContratoParams {
  const MarcarContratoParams({
    required this.id,
    required this.status,
    this.nomeAssinante = '',
  });

  final int id;
  final StatusContrato status;
  final String nomeAssinante;
}

class MarcarContratoUseCase implements UseCase<Contrato, MarcarContratoParams> {
  const MarcarContratoUseCase(this._repository);

  final ContratosRepository _repository;

  @override
  Future<Either<Failure, Contrato>> call(MarcarContratoParams params) =>
      _repository.marcar(
        params.id,
        params.status,
        nomeAssinante: params.nomeAssinante,
      );
}

class RemoverContratoUseCase implements UseCase<void, int> {
  const RemoverContratoUseCase(this._repository);

  final ContratosRepository _repository;

  @override
  Future<Either<Failure, void>> call(int id) => _repository.removerContrato(id);
}
