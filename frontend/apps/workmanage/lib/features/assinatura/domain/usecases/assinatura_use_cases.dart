import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/assinatura.dart';
import '../repositories/assinatura_repository.dart';

// os use cases da assinatura, um por ação, no mesmo arquivo porque cada um
// é uma linha sobre o repository

class ObterAssinaturaUseCase implements UseCase<Assinatura, NoParams> {
  const ObterAssinaturaUseCase(this._repository);

  final AssinaturaRepository _repository;

  @override
  Future<Either<Failure, Assinatura>> call(NoParams params) =>
      _repository.obter();
}

// devolve o link do checkout
class IniciarAssinaturaUseCase implements UseCase<String, NoParams> {
  const IniciarAssinaturaUseCase(this._repository);

  final AssinaturaRepository _repository;

  @override
  Future<Either<Failure, String>> call(NoParams params) =>
      _repository.iniciar();
}

// o parâmetro é o id da assinatura no gateway (preapproval_id)
class ConfirmarAssinaturaUseCase implements UseCase<Assinatura, String> {
  const ConfirmarAssinaturaUseCase(this._repository);

  final AssinaturaRepository _repository;

  @override
  Future<Either<Failure, Assinatura>> call(String params) =>
      _repository.confirmar(params);
}

class CancelarAssinaturaUseCase implements UseCase<Assinatura, NoParams> {
  const CancelarAssinaturaUseCase(this._repository);

  final AssinaturaRepository _repository;

  @override
  Future<Either<Failure, Assinatura>> call(NoParams params) =>
      _repository.cancelar();
}

class ListarPagamentosAssinaturaUseCase
    implements UseCase<List<PagamentoAssinatura>, NoParams> {
  const ListarPagamentosAssinaturaUseCase(this._repository);

  final AssinaturaRepository _repository;

  @override
  Future<Either<Failure, List<PagamentoAssinatura>>> call(NoParams params) =>
      _repository.listarPagamentos();
}
