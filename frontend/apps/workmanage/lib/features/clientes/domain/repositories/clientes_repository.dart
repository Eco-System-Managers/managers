import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/utils/lista_paginada.dart';

import '../entities/cliente.dart';

// contrato da ficha do cliente: o domain diz O QUE precisa, o data decide
// COMO. toda falha volta como Left(Failure), com a mensagem que a tela mostra
abstract class ClientesRepository {
  Future<Either<Failure, ListaPaginada<Cliente>>> listar({
    int pagina = 1,
    String? busca,
  });

  Future<Either<Failure, Cliente>> obter(int id);

  Future<Either<Failure, Cliente>> criar(Cliente cliente);

  Future<Either<Failure, Cliente>> atualizar(Cliente cliente);

  Future<Either<Failure, void>> remover(int id);
}
