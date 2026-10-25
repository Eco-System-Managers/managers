import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../params/logo_params.dart';
import '../repositories/empresa_repository.dart';

// devolve a URL pública da logo nova
class EnviarLogoUseCase implements UseCase<String, LogoParams> {
  const EnviarLogoUseCase(this._repository);

  final EmpresaRepository _repository;

  @override
  Future<Either<Failure, String>> call(LogoParams params) {
    return _repository.enviarLogo(params.bytes, params.nomeArquivo);
  }
}
