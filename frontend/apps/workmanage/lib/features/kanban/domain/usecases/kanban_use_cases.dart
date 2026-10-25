import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';

import '../entities/atendimento_kanban.dart';
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

class ListarAtendimentosDoDiaUseCase
    implements UseCase<List<AtendimentoKanban>, DateTime> {
  const ListarAtendimentosDoDiaUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, List<AtendimentoKanban>>> call(DateTime params) =>
      _repository.listarDoDia(params);
}

// o parâmetro é o id do cliente
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

class ListarSlotsKanbanUseCase implements UseCase<List<Hora>, DateTime> {
  const ListarSlotsKanbanUseCase(this._repository);

  final KanbanRepository _repository;

  @override
  Future<Either<Failure, List<Hora>>> call(DateTime params) =>
      _repository.slots(params);
}
