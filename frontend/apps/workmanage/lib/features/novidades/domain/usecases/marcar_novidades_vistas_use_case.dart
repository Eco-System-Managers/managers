import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/novidade.dart';
import '../repositories/novidades_repository.dart';

// guarda que este aparelho já mostrou as novidades desta versão. também é
// chamado na abertura sem sessão: quem instala do zero não tem novidade,
// tem o app inteiro
class MarcarNovidadesVistasUseCase implements UseCase<void, NoParams> {
  MarcarNovidadesVistasUseCase(this._repository);

  final NovidadesRepository _repository;

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    try {
      await _repository.marcarVista(versaoDasNovidades);
    } catch (_) {
      // não guardou: na próxima abertura a folha aparece de novo, o que
      // não vale um erro na tela
    }
    return const Right(null);
  }
}
