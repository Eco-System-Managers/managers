import 'package:dio/dio.dart';
import 'package:managers/core/session/sessao_model.dart';

// fala com /auth/cadastro/ da API. não trata erro: se a requisição falhar,
// a DioException sobe para o repository, que a traduz em Failure
abstract class RegisterRemoteDataSource {
  Future<void> register({
    required String nomeEmpresa,
    required String nome,
    required String email,
    required String senha,
  });

  // cria a empresa e devolve a sessão (access e refresh)
  Future<SessaoModel> confirm({required String email, required String code});

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

  // responde 201 com o schema Sessao, igual ao login
  @override
  Future<SessaoModel> confirm({
    required String email,
    required String code,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      'auth/cadastro/confirmar/',
      data: {'email': email, 'codigo': code},
    );
    return SessaoModel.fromJson(response.data!);
  }

  @override
  Future<void> resendCode(String email) async {
    await dio.post('auth/cadastro/reenviar/', data: {'email': email});
  }
}
