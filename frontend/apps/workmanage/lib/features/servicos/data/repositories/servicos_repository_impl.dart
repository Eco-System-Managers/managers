import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:managers/core/error/failure_mapper.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/servico.dart';
import '../../domain/repositories/servicos_repository.dart';
import '../datasources/servicos_remote_datasource.dart';
import '../models/servico_model.dart';

// implementa o contrato: chama o datasource, converte model em entidade e
// transforma qualquer erro em Failure
class ServicosRepositoryImpl implements ServicosRepository {
  ServicosRepositoryImpl(this._remoteDataSource);

  final ServicosRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<Servico>>> listar({String? busca, bool? ativo}) {
    return _executar(() async {
      final models = await _remoteDataSource.listar(busca: busca, ativo: ativo);
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, Servico>> obter(int id) {
    return _executar(() async {
      final model = await _remoteDataSource.obter(id);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, Servico>> criar(Servico servico) {
    return _executar(() async {
      final model = await _remoteDataSource.criar(
        ServicoModel.fromEntity(servico),
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, Servico>> atualizar(Servico servico) {
    return _executar(() async {
      final model = await _remoteDataSource.atualizar(
        servico.id,
        ServicoModel.fromEntity(servico),
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, Servico>> alterarAtivo(int id, bool ativo) {
    return _executar(() async {
      final model = await _remoteDataSource.alterarAtivo(id, ativo);
      return model.toEntity();
    });
  }

  // o try/catch é igual em todos os métodos: fica num lugar só
  Future<Either<Failure, T>> _executar<T>(Future<T> Function() acao) async {
    try {
      return Right(await acao());
    } on DioException catch (e) {
      return Left(failureFrom(e));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }
}
