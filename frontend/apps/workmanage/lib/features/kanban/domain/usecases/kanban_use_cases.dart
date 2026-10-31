import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';

import '../entities/atendimento_kanban.dart';
import '../entities/capacidade_do_dia.dart';
import '../entities/etapa.dart';
import '../params/kanban_params.dart';
import '../repositories/kanban_repository.dart';

// os use cases da esteira, um por ação, no mesmo arquivo porque cada um é
// uma linha sobre o repository

class ListarEtapasUseCase implements UseCase<List<Etapa>, NoParams> {
  const ListarEtapasUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, List<Etapa>>> call(NoParams params) =>
      _repository.listarEtapas();
}

class SalvarEtapaUseCase implements UseCase<Etapa, Etapa> {
  const SalvarEtapaUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, Etapa>> call(Etapa params) =>
      _repository.salvarEtapa(params);
}

class RemoverEtapaUseCase implements UseCase<void, int> {
  const RemoverEtapaUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, void>> call(int params) =>
      _repository.removerEtapa(params);
}

class ReordenarEtapasUseCase implements UseCase<void, List<int>> {
  const ReordenarEtapasUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, void>> call(List<int> params) =>
      _repository.reordenarEtapas(params);
}

class MarcarEtapaProntoUseCase implements UseCase<Etapa, int> {
  const MarcarEtapaProntoUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, Etapa>> call(int params) =>
      _repository.marcarEtapaPronto(params);
}

class ListarAtendimentosDoDiaUseCase
    implements UseCase<List<AtendimentoKanban>, ListarDoDiaParams> {
  const ListarAtendimentosDoDiaUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, List<AtendimentoKanban>>> call(
    ListarDoDiaParams params,
  ) =>
      _repository.listarDoDia(params.data, colaboradorId: params.colaboradorId);
}

class ListarAtendimentosKanbanDoClienteUseCase
    implements UseCase<List<AtendimentoKanban>, int> {
  const ListarAtendimentosKanbanDoClienteUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, List<AtendimentoKanban>>> call(int params) =>
      _repository.listarDoCliente(params);
}

class ObterAtendimentoKanbanUseCase implements UseCase<AtendimentoKanban, int> {
  const ObterAtendimentoKanbanUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, AtendimentoKanban>> call(int params) =>
      _repository.obter(params);
}

class CriarAtendimentoKanbanUseCase
    implements UseCase<AtendimentoKanban, NovoAtendimentoParams> {
  const CriarAtendimentoKanbanUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, AtendimentoKanban>> call(
    NovoAtendimentoParams params,
  ) => _repository.criar(params);
}

class MoverAtendimentoUseCase
    implements UseCase<AtendimentoKanban, MoverAtendimentoParams> {
  const MoverAtendimentoUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, AtendimentoKanban>> call(
    MoverAtendimentoParams params,
  ) => _repository.mover(params);
}

class RemarcarAtendimentoKanbanUseCase
    implements UseCase<AtendimentoKanban, RemarcarAtendimentoKanbanParams> {
  const RemarcarAtendimentoKanbanUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, AtendimentoKanban>> call(
    RemarcarAtendimentoKanbanParams params,
  ) => _repository.remarcar(params);
}

class AjustarTempoAtendimentoUseCase
    implements UseCase<AtendimentoKanban, AjustarTempoParams> {
  const AjustarTempoAtendimentoUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, AtendimentoKanban>> call(AjustarTempoParams params) =>
      _repository.ajustarTempo(params);
}

class CobrarAtendimentoKanbanUseCase
    implements UseCase<AtendimentoKanban, CobrancaParams> {
  const CobrarAtendimentoKanbanUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, AtendimentoKanban>> call(CobrancaParams params) =>
      _repository.cobrar(params);
}

class DesfazerCobrancaUseCase implements UseCase<AtendimentoKanban, int> {
  const DesfazerCobrancaUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, AtendimentoKanban>> call(int params) =>
      _repository.desfazerCobranca(params);
}

// true marca a falta, false desfaz
class AlterarFaltaParams {
  const AlterarFaltaParams({required this.id, required this.faltou});

  final int id;
  final bool faltou;
}

class AlterarFaltaUseCase
    implements UseCase<AtendimentoKanban, AlterarFaltaParams> {
  const AlterarFaltaUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, AtendimentoKanban>> call(AlterarFaltaParams params) =>
      params.faltou
      ? _repository.marcarFalta(params.id)
      : _repository.desfazerFalta(params.id);
}

class RemoverAtendimentoKanbanUseCase implements UseCase<void, int> {
  const RemoverAtendimentoKanbanUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, void>> call(int params) => _repository.remover(params);
}

class ListarSlotsKanbanUseCase
    implements UseCase<List<Hora>, SlotsKanbanParams> {
  const ListarSlotsKanbanUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, List<Hora>>> call(SlotsKanbanParams params) =>
      _repository.slots(params);
}

class ObterCapacidadeDoDiaUseCase
    implements UseCase<CapacidadeDoDia, DateTime> {
  const ObterCapacidadeDoDiaUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, CapacidadeDoDia>> call(DateTime params) =>
      _repository.capacidadeDoDia(params);
}

class AjustarCapacidadeDoDiaUseCase
    implements UseCase<CapacidadeDoDia, AjustarCapacidadeParams> {
  const AjustarCapacidadeDoDiaUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, CapacidadeDoDia>> call(
    AjustarCapacidadeParams params,
  ) => _repository.ajustarCapacidade(params);
}

class DesfazerAjusteDoDiaUseCase implements UseCase<CapacidadeDoDia, DateTime> {
  const DesfazerAjusteDoDiaUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, CapacidadeDoDia>> call(DateTime params) =>
      _repository.desfazerAjuste(params);
}
