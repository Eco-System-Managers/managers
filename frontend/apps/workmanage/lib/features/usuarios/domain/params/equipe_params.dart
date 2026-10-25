// os parâmetros das ações da equipe

class AtualizarFuncaoParams {
  const AtualizarFuncaoParams({required this.id, required this.funcao});

  final int id;
  final String funcao;
}

class AlterarAtivoColaboradorParams {
  const AlterarAtivoColaboradorParams({required this.id, required this.ativo});

  final int id;
  final bool ativo;
}

class NovoConviteParams {
  const NovoConviteParams({required this.nome, required this.email});

  final String nome;
  final String email;
}

// aceitar é definir a senha: a API cria o usuário e já devolve a sessão
class AceitarConviteParams {
  const AceitarConviteParams({required this.token, required this.senha});

  final String token;
  final String senha;
}
