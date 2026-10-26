import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:managers/core/error/failure_mapper.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/contrato.dart';
import '../../domain/entities/modelo_contrato.dart';
import '../../domain/repositories/contratos_repository.dart';
import '../datasources/contratos_remote_datasource.dart';
import '../models/modelo_contrato_model.dart';

class ContratosRepositoryImpl implements ContratosRepository {
  ContratosRepositoryImpl(this._remoteDataSource);

  final ContratosRemoteDataSource _remoteDataSource;

  // o try/catch de todo método mora aqui: traduz DioException em Failure
  Future<Either<Failure, T>> _executar<T>(Future<T> Function() acao) async {
    try {
      return Right(await acao());
    } on DioException catch (e) {
      return Left(failureFrom(e));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<ModeloContrato>>> listarModelos({bool? ativo}) =>
      _executar(() async {
        final modelos = await _remoteDataSource.listarModelos(ativo: ativo);
        return [for (final m in modelos) m.toEntity()];
      });

  @override
  Future<Either<Failure, ModeloContrato>> obterModelo(int id) => _executar(
    () async => (await _remoteDataSource.obterModelo(id)).toEntity(),
  );

  @override
  Future<Either<Failure, ModeloContrato>> criarModelo(ModeloContrato modelo) =>
      _executar(
        () async => (await _remoteDataSource.criarModelo(
          ModeloContratoModel.fromEntity(modelo),
        )).toEntity(),
      );

  @override
  Future<Either<Failure, ModeloContrato>> atualizarModelo(
    ModeloContrato modelo,
  ) => _executar(
    () async => (await _remoteDataSource.atualizarModelo(
      modelo.id,
      ModeloContratoModel.fromEntity(modelo),
    )).toEntity(),
  );

  @override
  Future<Either<Failure, ModeloContrato>> alterarAtivoModelo(
    int id,
    bool ativo,
  ) => _executar(
    () async =>
        (await _remoteDataSource.alterarAtivoModelo(id, ativo)).toEntity(),
  );

  @override
  Future<Either<Failure, List<Contrato>>> listarContratos({
    int? clienteId,
    StatusContrato? status,
  }) => _executar(() async {
    final contratos = await _remoteDataSource.listarContratos(
      clienteId: clienteId,
      status: status?.name,
    );
    return [for (final c in contratos) c.toEntity()];
  });

  @override
  Future<Either<Failure, Contrato>> obterContrato(int id) => _executar(
    () async => (await _remoteDataSource.obterContrato(id)).toEntity(),
  );

  @override
  Future<Either<Failure, Contrato>> gerar({
    required int modeloId,
    required int clienteId,
  }) => _executar(
    () async => (await _remoteDataSource.gerar(
      modeloId: modeloId,
      clienteId: clienteId,
    )).toEntity(),
  );

  @override
  Future<Either<Failure, Contrato>> marcar(
    int id,
    StatusContrato status, {
    String nomeAssinante = '',
  }) => _executar(
    () async => (await _remoteDataSource.marcar(
      id,
      status.name,
      nomeAssinante: nomeAssinante,
    )).toEntity(),
  );

  @override
  Future<Either<Failure, void>> removerContrato(int id) =>
      _executar(() => _remoteDataSource.removerContrato(id));
}
