import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/objeto_cliente.dart';
import '../repositories/clientes_repository.dart';

// os use cases dos objetos do cliente (veículo e pet), um por ação

// cria quando o id é 0, senão edita
class SalvarVeiculoUseCase implements UseCase<Veiculo, Veiculo> {
  const SalvarVeiculoUseCase(this._repository);

  final ClientesRepository _repository;

  @override
  Future<Either<Failure, Veiculo>> call(Veiculo params) =>
      _repository.salvarVeiculo(params);
}

class RemoverVeiculoUseCase implements UseCase<void, int> {
  const RemoverVeiculoUseCase(this._repository);

  final ClientesRepository _repository;

  @override
  Future<Either<Failure, void>> call(int params) =>
      _repository.removerVeiculo(params);
}

class SalvarPetUseCase implements UseCase<Pet, Pet> {
  const SalvarPetUseCase(this._repository);

  final ClientesRepository _repository;

  @override
  Future<Either<Failure, Pet>> call(Pet params) =>
      _repository.salvarPet(params);
}

class RemoverPetUseCase implements UseCase<void, int> {
  const RemoverPetUseCase(this._repository);

  final ClientesRepository _repository;

  @override
  Future<Either<Failure, void>> call(int params) =>
      _repository.removerPet(params);
}
