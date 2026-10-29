import 'package:dio/dio.dart';
import 'package:managers/core/session/sessao_model.dart';

// fala com /auth/ da API e devolve models. não trata erro: se a requisição
// falhar, a DioException sobe para o repository, que a traduz em Failure
abstract class AuthRemoteDataSource {
  Future<SessaoModel> login({required String email, required String senha});

  Future<void> sendRecoveryCode(String email);

  Future<void> verifyRecoveryCode({
    required String email,
    required String codigo,
  });

  Future<void> resetPassword({
    required String email,
    required String codigo,
    required String novaSenha,
  });

  Future<void> logout(String refresh);

  // pede a exclusão da conta de quem está logado (vai com Authorization)
  Future<void> excluirConta(String senha);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this.dio);

  final Dio dio;

  // a resposta é o schema Sessao, com o refresh no corpo porque o Dio manda
  // X-Client-Platform: mobile
  @override
  Future<SessaoModel> login({
    required String email,
    required String senha,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      'auth/login/',
      data: {'email': email, 'senha': senha},
    );
    return SessaoModel.fromJson(response.data!);
  }

  // responde sempre a mesma mensagem, exista ou não a conta
  @override
  Future<void> sendRecoveryCode(String email) async {
    await dio.post('auth/recuperar-senha/', data: {'email': email});
  }

  @override
  Future<void> verifyRecoveryCode({
    required String email,
    required String codigo,
  }) async {
    await dio.post(
      'auth/verificar-codigo/',
      data: {'email': email, 'codigo': codigo},
    );
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String codigo,
    required String novaSenha,
  }) async {
    await dio.post(
      'auth/nova-senha/',
      data: {'email': email, 'codigo': codigo, 'nova_senha': novaSenha},
    );
  }

  // vai sem Authorization (rota de auth): o que identifica a sessão é o
  // refresh no corpo
  @override
  Future<void> logout(String refresh) async {
    await dio.post('auth/logout/', data: {'refresh': refresh});
  }

  // fora de auth/: é a conta de quem está logado, então leva o token. a API
  // trava a conta na hora e apaga em 30 dias
  @override
  Future<void> excluirConta(String senha) async {
    await dio.post('colaboradores/me/excluir/', data: {'senha': senha});
  }
}
