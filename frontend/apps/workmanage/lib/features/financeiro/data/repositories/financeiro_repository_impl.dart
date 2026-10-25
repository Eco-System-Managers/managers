import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:managers/core/error/failure_mapper.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/caixa.dart';
import '../../domain/entities/saldo_cliente.dart';
import '../../domain/repositories/financeiro_repository.dart';
import '../datasources/financeiro_remote_datasource.dart';

class FinanceiroRepositoryImpl implements FinanceiroRepository {
  FinanceiroRepositoryImpl(this._remoteDataSource);

  final FinanceiroRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, Caixa>> caixa({
    DateTime? inicio,
    DateTime? fim,
    int? colaboradorId,
  }) {
    return _executar(
      () => _remoteDataSource.caixa(
        inicio: inicio,
        fim: fim,
        colaboradorId: colaboradorId,
      ),
    );
  }

  @override
  Future<Either<Failure, SaldoCliente>> saldoDoCliente(int clienteId) {
    return _executar(() => _remoteDataSource.saldoDoCliente(clienteId));
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
