import 'package:decimal/decimal.dart';

import '../entities/colaborador.dart';

// os parâmetros das ações da equipe

// o que o dono preenche de alguém da equipe, para criar ou editar
class DadosColaborador {
  const DadosColaborador({
    required this.nome,
    this.funcao = '',
    this.tipo = VinculoColaborador.parceiro,
    this.comissaoPercentual,
    this.podeCobrar = true,
  });

  final String nome;
  final String funcao;
  final VinculoColaborador tipo;
  final Decimal? comissaoPercentual;
  final bool podeCobrar;
}

class AtualizarColaboradorParams {
  const AtualizarColaboradorParams({required this.id, required this.dados});

  final int id;
  final DadosColaborador dados;
}

class AlterarAtivoColaboradorParams {
  const AlterarAtivoColaboradorParams({required this.id, required this.ativo});

  final int id;
  final bool ativo;
}

// dar login a quem já está na equipe: a API manda o convite para o e-mail
class ConvidarColaboradorParams {
  const ConvidarColaboradorParams({required this.id, required this.email});

  final int id;
  final String email;
}

// aceitar é definir a senha: a API cria o usuário e já devolve a sessão
class AceitarConviteParams {
  const AceitarConviteParams({required this.token, required this.senha});

  final String token;
  final String senha;
}
