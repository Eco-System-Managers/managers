import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao.dart';

import '../entities/colaborador.dart';
import '../entities/convite.dart';
import '../params/equipe_params.dart';

// contrato da equipe: o domain diz O QUE precisa, o data decide COMO.
// toda falha volta como Left(Failure), com a mensagem que a tela mostra
abstract class UsuariosRepository {
  // quem está logado, com o papel
  Future<Either<Failure, Colaborador>> buscarMeuPerfil();

  Future<Either<Failure, List<Colaborador>>> listarColaboradores({
    String? busca,
  });

  Future<Either<Failure, Colaborador>> obterColaborador(int id);

  // cadastrar alguém sem login (só o proprietário)
  Future<Either<Failure, Colaborador>> criarColaborador(DadosColaborador dados);

  // nome, função, vínculo, comissão e a flag de cobrar; ativo é pelas ações
  Future<Either<Failure, Colaborador>> atualizarColaborador(
    int id,
    DadosColaborador dados,
  );

  // dar login a quem já está na equipe
  Future<Either<Failure, Convite>> convidarColaborador(int id, String email);

  Future<Either<Failure, void>> ativarColaborador(int id);

  Future<Either<Failure, void>> desativarColaborador(int id);

  // agendamentos futuros que ficariam sem profissional ao remover
  Future<Either<Failure, int>> contarAgendamentosPendentes(int id);

  Future<Either<Failure, void>> removerColaborador(int id);

  // só os pendentes: a API não lista aceitos nem expirados
  Future<Either<Failure, List<Convite>>> listarConvites();

  Future<Either<Failure, Convite>> criarConvite({
    required String nome,
    required String email,
  });

  Future<Either<Failure, void>> cancelarConvite(int id);

  // rotas públicas, pelo token do link do e-mail
  Future<Either<Failure, ConviteInfo>> obterConvite(String token);

  Future<Either<Failure, Sessao>> aceitarConvite({
    required String token,
    required String senha,
  });
}
