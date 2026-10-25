import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';

import '../entities/colaborador.dart';

// contrato da equipe: o domain diz O QUE precisa, o data decide COMO.
// toda falha volta como Left(Failure), com a mensagem que a tela mostra
abstract class UsuariosRepository {
  // quem está logado, com o papel
  Future<Either<Failure, Colaborador>> buscarMeuPerfil();

  Future<Either<Failure, List<Colaborador>>> listarColaboradores({
    String? busca,
  });
}
