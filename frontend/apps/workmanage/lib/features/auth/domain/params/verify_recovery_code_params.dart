// a API confere o código junto com o e-mail que pediu a recuperação
class VerifyRecoveryCodeParams {
  const VerifyRecoveryCodeParams({required this.email, required this.codigo});

  final String email;
  final String codigo;
}
