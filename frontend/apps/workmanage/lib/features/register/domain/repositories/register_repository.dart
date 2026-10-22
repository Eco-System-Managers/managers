// contrato da autenticação: o domain diz O QUE precisa, o data decide COMO.
// toda falha é lançada como exceção; quem chama decide a mensagem
import 'package:dartz/dartz.dart';
import 'package:managers/features/register/domain/params/register_param.dart';

import '../../../../core/error/failures.dart';

abstract class RegisterRepository {
  Future<Either<Failure, void>> register(RegisterParam params);
}
