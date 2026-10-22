import 'package:dio/dio.dart';

abstract class RegisterRemoteDataSource {
  Future<void> register({
    required String nomeEmpresa,
    required String nome,
    required String email,
    required String senha,
  });
}

class RegisterRemoteDataSourceImpl implements RegisterRemoteDataSource {
  final Dio dio;

  RegisterRemoteDataSourceImpl(this.dio);

  @override
  Future<void> register({
    required String nomeEmpresa,
    required String nome,
    required String email,
    required String senha,
  }) async {
    await dio.post(
      'auth/cadastro/',
      data: {
        'nome_empresa': nomeEmpresa,
        'nome': nome,
        'email': email,
        'senha': senha,
      },
    );
  }
}
