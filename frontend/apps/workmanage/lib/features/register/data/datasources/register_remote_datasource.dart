import 'package:dio/dio.dart';

abstract class RegisterRemoteDataSource {
  Future<void> register({
    required String nomeEmpresa,
    required String nome,
    required String email,
    required String senha,
  });

  Future<void> confirm({required String email, required String code});

  Future<void> resendCode(String email);
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
    // a empresa ainda não é criada: o backend guarda os dados e manda o
    // código por e-mail. quem cria é o confirm
    await dio.post(
      'auth/cadastro/solicitar/',
      data: {
        'nome_empresa': nomeEmpresa,
        'nome': nome,
        'email': email,
        'senha': senha,
      },
    );
  }

  // cria a empresa e devolve a sessão (access e refresh)
  // TODO: guardar a sessão quando o app tiver onde (core)
  @override
  Future<void> confirm({required String email, required String code}) async {
    await dio.post(
      'auth/cadastro/confirmar/',
      data: {'email': email, 'codigo': code},
    );
  }

  @override
  Future<void> resendCode(String email) async {
    await dio.post('auth/cadastro/reenviar/', data: {'email': email});
  }
}
