import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';

import '../entities/assinatura.dart';

// contrato da assinatura: o domain diz O QUE precisa, o data decide COMO.
// toda falha volta como Left(Failure), com a mensagem que a tela mostra
abstract class AssinaturaRepository {
  // NotFoundFailure quando o negócio ainda não tem assinatura
  Future<Either<Failure, Assinatura>> obter();

  // o link do checkout, para abrir no navegador
  Future<Either<Failure, String>> iniciar();

  Future<Either<Failure, Assinatura>> confirmar(String idExterno);

  Future<Either<Failure, Assinatura>> cancelar();

  Future<Either<Failure, List<PagamentoAssinatura>>> listarPagamentos();
}
