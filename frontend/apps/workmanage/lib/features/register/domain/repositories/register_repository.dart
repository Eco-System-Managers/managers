// contrato do cadastro: o domain diz O QUE precisa, o data decide COMO.
// toda falha volta como Left(Failure), com a mensagem que a tela mostra
import 'package:dartz/dartz.dart';
import 'package:managers/core/session/sessao.dart';
import 'package:managers/features/register/domain/params/confirm_param.dart';
import 'package:managers/features/register/domain/params/register_param.dart';

import '../../../../core/error/failures.dart';

abstract class RegisterRepository {
  // envia os dados e dispara o código de confirmação por e-mail
  Future<Either<Failure, void>> register(RegisterParam params);

  // confere o código: só aqui a empresa é criada. devolve a sessão;
  // guardá-la é com quem chama (SessaoController)
  Future<Either<Failure, Sessao>> confirm(ConfirmParam params);

  Future<Either<Failure, void>> resendCode(String email);
}
