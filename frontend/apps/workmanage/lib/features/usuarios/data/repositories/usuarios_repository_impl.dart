import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:managers/core/error/failure_mapper.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/colaborador.dart';
import '../../domain/repositories/usuarios_repository.dart';
import '../datasources/usuarios_remote_datasource.dart';

// implementa o contrato: chama o datasource, converte model em entidade e
// transforma qualquer erro em Failure
class UsuariosRepositoryImpl implements UsuariosRepository {
  UsuariosRepositoryImpl(this._remoteDataSource);

  final UsuariosRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, Colaborador>> buscarMeuPerfil() {
    return _executar(() async {
      final model = await _remoteDataSource.meuPerfil();
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, List<Colaborador>>> listarColaboradores({
    String? busca,
  }) {
    return _executar(() async {
      final models = await _remoteDataSource.listar(busca: busca);
      return models.map((m) => m.toEntity()).toList();
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
