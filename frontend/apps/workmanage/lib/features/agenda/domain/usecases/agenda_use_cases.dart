import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';

import '../entities/agendamento.dart';
import '../entities/pendencia_cobranca.dart';
import '../entities/slot.dart';
import '../params/agenda_params.dart';
import '../repositories/agenda_repository.dart';

// os use cases da agenda, um por ação, no mesmo arquivo porque cada um é
// uma linha sobre o repository

class ListarAgendamentosDoDiaParams {
  const ListarAgendamentosDoDiaParams({required this.data, this.colaboradorId});

  final DateTime data;
  final int? colaboradorId;
}

class ListarAgendamentosDoDiaUseCase
    implements UseCase<List<Agendamento>, ListarAgendamentosDoDiaParams> {
  const ListarAgendamentosDoDiaUseCase(this._repository);

  final AgendaRepository _repository;

  @override
  Future<Either<Failure, List<Agendamento>>> call(
    ListarAgendamentosDoDiaParams params,
  ) {
    return _repository.listarDoDia(
      params.data,
      colaboradorId: params.colaboradorId,
    );
  }
}

// o parâmetro é o id do cliente
class ListarAgendamentosDoClienteUseCase
    implements UseCase<List<Agendamento>, int> {
  const ListarAgendamentosDoClienteUseCase(this._repository);

  final AgendaRepository _repository;

  @override
  Future<Either<Failure, List<Agendamento>>> call(int params) =>
      _repository.listarDoCliente(params);
}

class ObterAgendamentoUseCase implements UseCase<Agendamento, int> {
  const ObterAgendamentoUseCase(this._repository);

  final AgendaRepository _repository;

  @override
  Future<Either<Failure, Agendamento>> call(int params) =>
      _repository.obter(params);
}

class CriarAgendamentoUseCase
    implements UseCase<Agendamento, NovoAgendamentoParams> {
  const CriarAgendamentoUseCase(this._repository);

  final AgendaRepository _repository;

  @override
  Future<Either<Failure, Agendamento>> call(NovoAgendamentoParams params) =>
      _repository.criar(params);
}

class AlterarStatusAgendamentoUseCase
    implements UseCase<Agendamento, AlterarStatusParams> {
  const AlterarStatusAgendamentoUseCase(this._repository);

  final AgendaRepository _repository;

  @override
  Future<Either<Failure, Agendamento>> call(AlterarStatusParams params) =>
      _repository.alterarStatus(params);
}

class RemarcarAgendamentoUseCase
    implements UseCase<Agendamento, RemarcarParams> {
  const RemarcarAgendamentoUseCase(this._repository);

  final AgendaRepository _repository;

  @override
  Future<Either<Failure, Agendamento>> call(RemarcarParams params) =>
      _repository.remarcar(params);
}

class CobrarAgendamentoUseCase implements UseCase<Agendamento, CobrancaParams> {
  const CobrarAgendamentoUseCase(this._repository);

  final AgendaRepository _repository;

  @override
  Future<Either<Failure, Agendamento>> call(CobrancaParams params) =>
      _repository.cobrar(params);
}

class ListarSlotsUseCase implements UseCase<List<Slot>, SlotsParams> {
  const ListarSlotsUseCase(this._repository);

  final AgendaRepository _repository;

  @override
  Future<Either<Failure, List<Slot>>> call(SlotsParams params) =>
      _repository.slots(params);
}

class ListarDiasComRegistroUseCase
    implements UseCase<List<DateTime>, MesParams> {
  const ListarDiasComRegistroUseCase(this._repository);

  final AgendaRepository _repository;

  @override
  Future<Either<Failure, List<DateTime>>> call(MesParams params) =>
      _repository.diasComRegistro(params);
}

class ListarPendenciasUseCase
    implements UseCase<List<PendenciaCobranca>, NoParams> {
  const ListarPendenciasUseCase(this._repository);

  final AgendaRepository _repository;

  @override
  Future<Either<Failure, List<PendenciaCobranca>>> call(NoParams params) =>
      _repository.pendencias();
}
