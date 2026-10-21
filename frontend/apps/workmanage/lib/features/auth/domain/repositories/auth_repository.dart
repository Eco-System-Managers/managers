// contrato da autenticação: o domain diz O QUE precisa, o data decide COMO.
// toda falha é lançada como exceção; quem chama decide a mensagem
abstract class AuthRepository {
  Future<void> login(String email, String password);

  // também usado para reenviar o código
  Future<void> sendRecoveryCode(String email);

  Future<void> verifyRecoveryCode(String code);

  Future<void> resetPassword(String email, String password);
}
