import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';

import '../entities/dashboard_resumo.dart';

abstract class DashboardRepository {
  // sem datas a API usa hoje; sem colaborador, todos (ou o próprio, para
  // quem não é proprietário)
  Future<Either<Failure, DashboardResumo>> resumo({
    DateTime? inicio,
    DateTime? fim,
    int? colaboradorId,
  });
}
