import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';

import '../entities/caixa.dart';
import '../entities/saldo_cliente.dart';

// contrato do financeiro: o domain diz O QUE precisa, o data decide COMO
abstract class FinanceiroRepository {
  Future<Either<Failure, Caixa>> caixa({
    DateTime? inicio,
    DateTime? fim,
    int? colaboradorId,
  });

  Future<Either<Failure, SaldoCliente>> saldoDoCliente(int clienteId);
}
