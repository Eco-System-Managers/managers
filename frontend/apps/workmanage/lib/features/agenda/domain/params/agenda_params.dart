import 'package:managers/core/utils/datas.dart';

import '../entities/agendamento.dart';

// o que marca um agendamento: um ou mais serviços, feitos em sequência
// pelo mesmo profissional. a API congela o preço de cada um na hora
class NovoAgendamentoParams {
  const NovoAgendamentoParams({
    required this.clienteId,
    required this.servicoIds,
    required this.colaboradorId,
    required this.dataHora,
    this.observacoes = '',
  });

  final int clienteId;
  final List<int> servicoIds;
  final int? colaboradorId;
  final DateTime dataHora;
  final String observacoes;
}

// a lista nova inteira, antes do atendimento: quem fica mantém o preço
// combinado, quem entra vem com o preço atual
class TrocarServicosParams {
  const TrocarServicosParams({required this.id, required this.servicoIds});

  final int id;
  final List<int> servicoIds;
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

// a grade cabe a soma das durações dos serviços
class SlotsParams {
  const SlotsParams({
    required this.data,
    required this.servicoIds,
    required this.colaboradorId,
  });

  final DateTime data;
  final List<int> servicoIds;
  final int colaboradorId;
}

// o que cria um bloqueio. "uma semana" e "um mês" chegam aqui como dataFim;
// dataFim null é o fixo, horas null são o dia inteiro. colaboradorId null é
// o bloqueio do negócio inteiro (só o proprietário)
class NovoBloqueioParams {
  const NovoBloqueioParams({
    required this.dataInicio,
    this.colaboradorId,
    this.dataFim,
    this.horaInicio,
    this.horaFim,
    this.motivo = '',
  });

  final int? colaboradorId;
  final DateTime dataInicio;
  final DateTime? dataFim;
  final Hora? horaInicio;
  final Hora? horaFim;
  final String motivo;
}

class MesParams {
  const MesParams({required this.ano, required this.mes});

  final int ano;
  final int mes;
}
