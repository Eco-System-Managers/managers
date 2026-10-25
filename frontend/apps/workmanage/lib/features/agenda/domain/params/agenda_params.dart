import '../entities/agendamento.dart';

// o que marca um agendamento: a API aceita um serviço por agendamento
// (campo servico_id) e congela o preço dele na hora
class NovoAgendamentoParams {
  const NovoAgendamentoParams({
    required this.clienteId,
    required this.servicoId,
    required this.colaboradorId,
    required this.dataHora,
    this.observacoes = '',
  });

  final int clienteId;
  final int servicoId;
  final int? colaboradorId;
  final DateTime dataHora;
  final String observacoes;
}

class AlterarStatusParams {
  const AlterarStatusParams({required this.id, required this.status});

  final int id;
  final StatusAgendamento status;
}

// remarcar: nova data e hora, e o profissional (pode ser o mesmo)
class RemarcarParams {
  const RemarcarParams({
    required this.id,
    required this.dataHora,
    required this.colaboradorId,
  });

  final int id;
  final DateTime dataHora;
  final int? colaboradorId;
}

class SlotsParams {
  const SlotsParams({
    required this.data,
    required this.servicoId,
    required this.colaboradorId,
  });

  final DateTime data;
  final int servicoId;
  final int colaboradorId;
}

class MesParams {
  const MesParams({required this.ano, required this.mes});

  final int ano;
  final int mes;
}
