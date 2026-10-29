import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao.dart';

// contrato da autenticação: o domain diz O QUE precisa, o data decide COMO.
// toda falha volta como Left(Failure), com a mensagem que a tela mostra
abstract class AuthRepository {
  // devolve a sessão; guardá-la é com quem chama (SessaoController)
  Future<Either<Failure, Sessao>> login(String email, String senha);

  Future<Either<Failure, void>> sendRecoveryCode(String email);

  Future<Either<Failure, void>> verifyRecoveryCode(String email, String codigo);

  Future<Either<Failure, void>> resetPassword(
    String email,
    String codigo,
    String novaSenha,
  );

  // revoga o refresh na API. a sessão local é limpa por quem chama, dê
  // certo ou não
  Future<Either<Failure, void>> logout(String refresh);

  // do dono, o negócio inteiro; da equipe, só o login. a conta trava na hora
  // e é apagada em 30 dias; entrar de novo antes disso desiste
  Future<Either<Failure, void>> excluirConta(String senha);
}
