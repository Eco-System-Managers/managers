import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/caixa.dart';
import '../entities/saldo_cliente.dart';
import '../repositories/financeiro_repository.dart';

// o período do caixa. sem datas, hoje
class CaixaParams {
  const CaixaParams({this.inicio, this.fim, this.colaboradorId});

  final DateTime? inicio;
  final DateTime? fim;
  final int? colaboradorId;
}

class ObterCaixaUseCase implements UseCase<Caixa, CaixaParams> {
  const ObterCaixaUseCase(this._repository);

  final FinanceiroRepository _repository;

  @override
  Future<Either<Failure, Caixa>> call(CaixaParams params) {
    return _repository.caixa(
      inicio: params.inicio,
      fim: params.fim,
      colaboradorId: params.colaboradorId,
    );
  }
}

class ObterSaldoClienteUseCase implements UseCase<SaldoCliente, int> {
  const ObterSaldoClienteUseCase(this._repository);

  final FinanceiroRepository _repository;

  @override
  Future<Either<Failure, SaldoCliente>> call(int params) =>
      _repository.saldoDoCliente(params);
}
