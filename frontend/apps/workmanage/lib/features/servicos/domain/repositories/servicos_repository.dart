import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';

import '../entities/servico.dart';

// contrato do catálogo: o domain diz O QUE precisa, o data decide COMO.
// toda falha volta como Left(Failure), com a mensagem que a tela mostra
abstract class ServicosRepository {
  Future<Either<Failure, List<Servico>>> listar({String? busca, bool? ativo});

  Future<Either<Failure, Servico>> obter(int id);

  Future<Either<Failure, Servico>> criar(Servico servico);

  Future<Either<Failure, Servico>> atualizar(Servico servico);

  Future<Either<Failure, Servico>> alterarAtivo(int id, bool ativo);
}
