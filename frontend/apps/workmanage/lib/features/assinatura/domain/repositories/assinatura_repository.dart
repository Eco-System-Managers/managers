import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';

import '../entities/assinatura.dart';

// contrato da assinatura na API: o domain diz O QUE precisa, o data decide
// COMO. toda falha volta como Left(Failure), com a mensagem que a tela mostra
abstract class AssinaturaRepository {
  // NotFoundFailure quando o negócio ainda não tem assinatura
  Future<Either<Failure, Assinatura>> obter();

  // pede à API para ler na loja o que o negócio comprou: o acesso libera na
  // hora, sem esperar o aviso da loja chegar ao servidor
  Future<Either<Failure, Assinatura>> sincronizar();

  Future<Either<Failure, List<PagamentoAssinatura>>> listarPagamentos();
}
