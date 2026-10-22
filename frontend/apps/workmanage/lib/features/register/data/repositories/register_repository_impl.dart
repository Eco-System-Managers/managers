import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:managers/features/register/domain/params/register_param.dart';

import '../../../../core/error/failures.dart';
import '../../domain/repositories/register_repository.dart';
import '../datasources/register_remote_datasource.dart';

class RegisterRepositoryImpl implements RegisterRepository {
  final RegisterRemoteDataSource remoteDataSource;

  RegisterRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, void>> register(RegisterParam params) async {
    try {
      await remoteDataSource.register(
        nomeEmpresa: params.nomeEmpresa,
        nome: params.nome,
        email: params.email,
        senha: params.senha,
      );

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

    // o DRF devolve {"detail": "..."} ou {"campo": ["mensagem", ...]}
    final data = response.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return detail;

      for (final value in data.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String) return value;
      }
    }

    return 'Erro no servidor (${response.statusCode}). Tente novamente.';
  }
}
