import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  // TODO: trocar as simulações pelas chamadas ao datasource remoto

  @override
  Future<void> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1)); // simulação
  }

  @override
  Future<void> sendRecoveryCode(String email) async {
    await Future.delayed(const Duration(seconds: 1)); // simulação
  }

  @override
  Future<void> verifyRecoveryCode(String code) async {
    await Future.delayed(const Duration(seconds: 1)); // simulação
    // simulação de erro: "000000" sempre falha, para testar a mensagem
    if (code == '000000') throw Exception('código inválido');
  }

  @override
  Future<void> resetPassword(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1)); // simulação
  }

  @override
  Future<void> register(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1)); // simulação
  }

}
