import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';

import '../entities/agendamento.dart';
import '../entities/pendencia_cobranca.dart';
import '../entities/slot.dart';
import '../params/agenda_params.dart';

// contrato da agenda por horário: o domain diz O QUE precisa, o data decide
// COMO. toda falha volta como Left(Failure), com a mensagem que a tela mostra
abstract class AgendaRepository {
  Future<Either<Failure, List<Agendamento>>> listarDoDia(
    DateTime data, {
    int? colaboradorId,
  });

  Future<Either<Failure, Agendamento>> obter(int id);

  Future<Either<Failure, Agendamento>> criar(NovoAgendamentoParams params);

  // agendado -> confirmado -> concluído; cancelado e faltou. cancelar é
  // mudar o status, não apagar: o histórico fica e o app do cliente é avisado
  Future<Either<Failure, Agendamento>> alterarStatus(
    AlterarStatusParams params,
  );

  Future<Either<Failure, Agendamento>> remarcar(RemarcarParams params);

  Future<Either<Failure, Agendamento>> cobrar(CobrancaParams params);

  Future<Either<Failure, List<Slot>>> slots(SlotsParams params);

  Future<Either<Failure, List<DateTime>>> diasComRegistro(MesParams params);

  Future<Either<Failure, List<PendenciaCobranca>>> pendencias();
}
