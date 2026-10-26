import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:managers/core/error/failure_mapper.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';

import '../../domain/entities/atendimento_kanban.dart';
import '../../domain/entities/etapa.dart';
import '../../domain/params/kanban_params.dart';
import '../../domain/repositories/kanban_repository.dart';
import '../datasources/kanban_remote_datasource.dart';

// implementa o contrato: chama o datasource, converte model em entidade e
// transforma qualquer erro em Failure
class KanbanRepositoryImpl implements KanbanRepository {
  KanbanRepositoryImpl(this._remoteDataSource);

  final KanbanRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<Etapa>>> listarEtapas() {
    return _executar(() async {
      final models = await _remoteDataSource.listarEtapas();
      return models.map((m) => m.toEntity()).toList()
        ..sort((a, b) => a.ordem.compareTo(b.ordem));
    });
  }

  @override
  Future<Either<Failure, Etapa>> salvarEtapa(Etapa etapa) {
    return _executar(() async {
      final model = etapa.ehNova
          ? await _remoteDataSource.criarEtapa(etapa)
          : await _remoteDataSource.atualizarEtapa(etapa);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> removerEtapa(int id) =>
      _executar(() => _remoteDataSource.removerEtapa(id));

  @override
  Future<Either<Failure, void>> reordenarEtapas(List<int> ids) =>
      _executar(() => _remoteDataSource.reordenarEtapas(ids));

  @override
  Future<Either<Failure, List<AtendimentoKanban>>> listarDoDia(
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
  Future<Either<Failure, List<AtendimentoKanban>>> listarDoCliente(
    int clienteId,
  ) {
    return _executar(() async {
      final models = await _remoteDataSource.listarDoCliente(clienteId);
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, AtendimentoKanban>> obter(int id) =>
      _executar(() async => (await _remoteDataSource.obter(id)).toEntity());

  @override
  Future<Either<Failure, AtendimentoKanban>> criar(
    NovoAtendimentoParams params,
  ) =>
      _executar(() async => (await _remoteDataSource.criar(params)).toEntity());

  @override
  Future<Either<Failure, AtendimentoKanban>> mover(
    MoverAtendimentoParams params,
  ) {
    return _executar(() async {
      final model = await _remoteDataSource.mover(params.id, params.etapaId);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, AtendimentoKanban>> cobrar(CobrancaParams params) =>
      _executar(
        () async => (await _remoteDataSource.cobrar(params)).toEntity(),
      );

  @override
  Future<Either<Failure, AtendimentoKanban>> desfazerCobranca(int id) =>
      _executar(
        () async => (await _remoteDataSource.desfazerCobranca(id)).toEntity(),
      );

  @override
  Future<Either<Failure, AtendimentoKanban>> marcarFalta(int id) => _executar(
    () async => (await _remoteDataSource.marcarFalta(id)).toEntity(),
  );

  @override
  Future<Either<Failure, AtendimentoKanban>> desfazerFalta(int id) => _executar(
    () async => (await _remoteDataSource.desfazerFalta(id)).toEntity(),
  );

  @override
  Future<Either<Failure, void>> remover(int id) =>
      _executar(() => _remoteDataSource.remover(id));

  @override
  Future<Either<Failure, List<Hora>>> slots(DateTime data) =>
      _executar(() => _remoteDataSource.slots(data));

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
