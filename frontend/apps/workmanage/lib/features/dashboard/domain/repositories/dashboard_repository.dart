import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';

import '../entities/dashboard_resumo.dart';

abstract class DashboardRepository {
  Future<Either<Failure, DashboardResumo>> resumo();
}
