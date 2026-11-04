class RegisterParam {
  final String nomeEmpresa;
  final String nome;
  final String email;
  final String senha;

  // o e-mail que já recebeu um código neste cadastro, quando a pessoa voltou
  // para corrigir: a API descarta o pendente dele
  final String? emailAnterior;

  RegisterParam({
    required this.nomeEmpresa,
    required this.nome,
    required this.email,
    required this.senha,
    this.emailAnterior,
  });
}
