import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:managers/core/error/failure_mapper.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao.dart';

import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

// implementa o contrato: chama o datasource, converte model em entidade e
// transforma qualquer erro em Failure
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remoteDataSource);

  final AuthRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, Sessao>> login(String email, String senha) {
    return _executar(() async {
      final model = await _remoteDataSource.login(email: email, senha: senha);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> sendRecoveryCode(String email) {
    return _executarSemRetorno(() => _remoteDataSource.sendRecoveryCode(email));
  }

  @override
  Future<Either<Failure, void>> verifyRecoveryCode(
    String email,
    String codigo,
  ) {
    return _executarSemRetorno(
      () => _remoteDataSource.verifyRecoveryCode(email: email, codigo: codigo),
    );
  }

  @override
  Future<Either<Failure, void>> resetPassword(
    String email,
    String codigo,
    String novaSenha,
  ) {
    return _executarSemRetorno(
      () => _remoteDataSource.resetPassword(
        email: email,
        codigo: codigo,
        novaSenha: novaSenha,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> logout(String refresh) {
    return _executarSemRetorno(() => _remoteDataSource.logout(refresh));
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
