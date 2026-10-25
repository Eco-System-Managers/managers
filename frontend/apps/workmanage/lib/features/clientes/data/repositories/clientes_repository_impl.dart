import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:managers/core/error/failure_mapper.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/utils/lista_paginada.dart';

import '../../domain/entities/cliente.dart';
import '../../domain/repositories/clientes_repository.dart';
import '../datasources/clientes_remote_datasource.dart';
import '../models/cliente_model.dart';

// implementa o contrato: chama o datasource, converte model em entidade e
// transforma qualquer erro em Failure
class ClientesRepositoryImpl implements ClientesRepository {
  ClientesRepositoryImpl(this._remoteDataSource);

  final ClientesRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, ListaPaginada<Cliente>>> listar({
    int pagina = 1,
    String? busca,
  }) {
    return _executar(() async {
      final page = await _remoteDataSource.listar(pagina: pagina, busca: busca);
      return ListaPaginada(
        itens: page.results.map((m) => m.toEntity()).toList(),
        total: page.count,
        temMais: page.next != null,
      );
    });
  }

  @override
  Future<Either<Failure, Cliente>> obter(int id) {
    return _executar(() async {
      final model = await _remoteDataSource.obter(id);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, Cliente>> criar(Cliente cliente) {
    return _executar(() async {
      final model = await _remoteDataSource.criar(
        ClienteModel.fromEntity(cliente),
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, Cliente>> atualizar(Cliente cliente) {
    return _executar(() async {
      final model = await _remoteDataSource.atualizar(
        cliente.id,
        ClienteModel.fromEntity(cliente),
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> remover(int id) async {
    try {
      await _remoteDataSource.remover(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(failureFrom(e));
    } catch (_) {
      return const Left(ServerFailure());
    }
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
