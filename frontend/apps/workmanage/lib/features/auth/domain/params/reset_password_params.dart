// a troca de senha leva o código de novo: é ele que autoriza a troca
class ResetPasswordParams {
  const ResetPasswordParams({
    required this.email,
    required this.codigo,
    required this.novaSenha,
  });

  final String email;
  final String codigo;
  final String novaSenha;
}
