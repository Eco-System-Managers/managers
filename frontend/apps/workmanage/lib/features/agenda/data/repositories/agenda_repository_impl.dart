import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:managers/core/error/failure_mapper.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/utils/datas.dart';

import '../../domain/entities/agendamento.dart';
import '../../domain/entities/pendencia_cobranca.dart';
import '../../domain/entities/slot.dart';
import '../../domain/params/agenda_params.dart';
import '../../domain/repositories/agenda_repository.dart';
import '../datasources/agenda_remote_datasource.dart';

// implementa o contrato: chama o datasource, converte model em entidade e
// transforma qualquer erro em Failure
class AgendaRepositoryImpl implements AgendaRepository {
  AgendaRepositoryImpl(this._remoteDataSource);

  final AgendaRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<Agendamento>>> listarDoDia(
    DateTime data, {
    int? colaboradorId,
  }) {
    return _executar(() async {
      final models = await _remoteDataSource.listarDoDia(
        data,
        colaboradorId: colaboradorId,
      );
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, List<Agendamento>>> listarDoCliente(int clienteId) {
    return _executar(() async {
      final models = await _remoteDataSource.listarDoCliente(clienteId);
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, Agendamento>> obter(int id) {
    return _executar(
      () async => (await _remoteDataSource.obter(id)).toEntity(),
    );
  }

  @override
  Future<Either<Failure, Agendamento>> criar(NovoAgendamentoParams params) {
    return _executar(
      () async => (await _remoteDataSource.criar(params)).toEntity(),
    );
  }

  @override
  Future<Either<Failure, Agendamento>> alterarStatus(
    AlterarStatusParams params,
  ) {
    return _executar(() async {
      final model = await _remoteDataSource.atualizar(params.id, {
        'status': params.status.name,
      });
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, Agendamento>> remarcar(RemarcarParams params) {
    return _executar(() async {
      final model = await _remoteDataSource.atualizar(params.id, {
        'data_hora': dataHoraParaApi(params.dataHora),
        'colaborador': params.colaboradorId,
      });
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, Agendamento>> cobrar(CobrancaParams params) {
    return _executar(
      () async => (await _remoteDataSource.cobrar(params)).toEntity(),
    );
  }

  @override
  Future<Either<Failure, List<Slot>>> slots(SlotsParams params) {
    return _executar(() => _remoteDataSource.slots(params));
  }

  @override
  Future<Either<Failure, List<DateTime>>> diasComRegistro(MesParams params) {
    return _executar(() => _remoteDataSource.diasComRegistro(params));
  }

  @override
  Future<Either<Failure, List<PendenciaCobranca>>> pendencias() {
    return _executar(_remoteDataSource.pendencias);
  }

  // o try/catch é igual em todos os métodos: fica num lugar só
  Future<Either<Failure, T>> _executar<T>(Future<T> Function() acao) async {
    try {
      return Right(await acao());
    } on DioException catch (e) {
      return Left(failureFrom(e));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }
}
