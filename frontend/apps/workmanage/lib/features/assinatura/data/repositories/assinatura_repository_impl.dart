import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:managers/core/error/failure_mapper.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/assinatura.dart';
import '../../domain/repositories/assinatura_repository.dart';
import '../datasources/assinatura_remote_datasource.dart';

class AssinaturaRepositoryImpl implements AssinaturaRepository {
  AssinaturaRepositoryImpl(this._remoteDataSource);

  final AssinaturaRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, Assinatura>> obter() =>
      _executar(_remoteDataSource.obter);

  @override
  Future<Either<Failure, String>> iniciar() =>
      _executar(_remoteDataSource.iniciar);

  @override
  Future<Either<Failure, Assinatura>> confirmar(String idExterno) =>
      _executar(() => _remoteDataSource.confirmar(idExterno));

  @override
  Future<Either<Failure, Assinatura>> cancelar() =>
      _executar(_remoteDataSource.cancelar);

  @override
  Future<Either<Failure, List<PagamentoAssinatura>>> listarPagamentos() =>
      _executar(_remoteDataSource.listarPagamentos);

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
