import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:managers/core/error/failure_mapper.dart';
import 'package:managers/core/session/sessao.dart';
import 'package:managers/features/register/domain/params/confirm_param.dart';
import 'package:managers/features/register/domain/params/register_param.dart';

import '../../../../core/error/failures.dart';
import '../../domain/repositories/register_repository.dart';
import '../datasources/register_remote_datasource.dart';

class RegisterRepositoryImpl implements RegisterRepository {
  final RegisterRemoteDataSource remoteDataSource;

  RegisterRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, void>> register(RegisterParam params) {
    return _executarSemRetorno(
      () => remoteDataSource.register(
        nomeEmpresa: params.nomeEmpresa,
        nome: params.nome,
        email: params.email,
        senha: params.senha,
      ),
    );
  }

  @override
  Future<Either<Failure, Sessao>> confirm(ConfirmParam params) {
    return _executar(() async {
      final model = await remoteDataSource.confirm(
        email: params.email,
        code: params.code,
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> resendCode(String email) {
    return _executarSemRetorno(() => remoteDataSource.resendCode(email));
  }

  // o try/catch é igual em todos os métodos: fica num lugar só. a tradução
  // do erro em Failure é a mesma do app inteiro (core/error/failure_mapper)
  Future<Either<Failure, T>> _executar<T>(Future<T> Function() acao) async {
    try {
      return Right(await acao());
    } on DioException catch (e) {
      return Left(failureFrom(e));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  Future<Either<Failure, void>> _executarSemRetorno(
    Future<void> Function() acao,
  ) async {
    try {
      await acao();
      return const Right(null);
    } on DioException catch (e) {
      return Left(failureFrom(e));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }
}
