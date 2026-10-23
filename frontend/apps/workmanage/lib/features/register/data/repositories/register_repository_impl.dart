import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
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
    return _run(
      () => remoteDataSource.register(
        nomeEmpresa: params.nomeEmpresa,
        nome: params.nome,
        email: params.email,
        senha: params.senha,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> confirm(ConfirmParam params) {
    return _run(
      () => remoteDataSource.confirm(email: params.email, code: params.code),
    );
  }

  @override
  Future<Either<Failure, void>> resendCode(String email) {
    return _run(() => remoteDataSource.resendCode(email));
  }

  // o try/catch é igual em todos os métodos: fica num lugar só
  Future<Either<Failure, void>> _run(Future<void> Function() action) async {
    try {
      await action();
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(_messageFrom(e)));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  // traduz o erro do Dio numa mensagem que a tela pode mostrar
  String _messageFrom(DioException e) {
    final response = e.response;

    // sem resposta: a requisição nem chegou na API (rede, timeout, URL)
    if (response == null) {
      return 'Não foi possível conectar ao servidor.';
    }

    // contrato de erro da API: {"detail", "code", "fields"?}. em erro de
    // validação o detail é genérico ("Dados inválidos.") e o motivo real
    // fica em fields: {"campo": ["mensagem", ...]}
    final data = response.data;
    if (data is Map) {
      final fields = data['fields'];
      if (fields is Map) {
        for (final value in fields.values) {
          if (value is List && value.isNotEmpty) return value.first.toString();
          if (value is String) return value;
        }
      }

      final detail = data['detail'];
      if (detail is String) return detail;
    }

    return 'Erro no servidor (${response.statusCode}). Tente novamente.';
  }
}
