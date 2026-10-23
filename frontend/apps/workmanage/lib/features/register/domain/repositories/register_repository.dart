// contrato da autenticação: o domain diz O QUE precisa, o data decide COMO.
// toda falha é lançada como exceção; quem chama decide a mensagem
import 'package:dartz/dartz.dart';
import 'package:managers/features/register/domain/params/confirm_param.dart';
import 'package:managers/features/register/domain/params/register_param.dart';

import '../../../../core/error/failures.dart';

abstract class RegisterRepository {
  // envia os dados e dispara o código de confirmação por e-mail
  Future<Either<Failure, void>> register(RegisterParam params);

  // confere o código: só aqui a empresa é criada
  Future<Either<Failure, void>> confirm(ConfirmParam params);

  Future<Either<Failure, void>> resendCode(String email);
}
