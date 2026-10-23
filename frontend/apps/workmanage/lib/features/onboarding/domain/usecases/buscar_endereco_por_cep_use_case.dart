import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/endereco.dart';
import '../repositories/onboarding_repository.dart';

class BuscarEnderecoPorCepUseCase implements UseCase<Endereco, String> {
  const BuscarEnderecoPorCepUseCase(this._repository);

  final OnboardingRepository _repository;

  // a tela manda o CEP com máscara (00000-000); a busca recebe só os dígitos
  @override
  Future<Either<Failure, Endereco>> call(String params) {
    final cep = params.replaceAll(RegExp(r'\D'), '');
    return _repository.buscarEnderecoPorCep(cep);
  }
}
