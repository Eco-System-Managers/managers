import 'package:managers/core/utils/datas.dart';

// receber um atendimento: entra numa etapa (a primeira), com o objeto do
// cliente e um serviço, ou avulso (sem objeto, só a identificação). a hora
// de entrada é opcional
class NovoAtendimentoParams {
  const NovoAtendimentoParams({
    required this.etapaId,
    this.objetoId,
    this.identificacao = '',
    required this.servicoId,
    required this.data,
    this.horarioEntrada,
    this.colaboradorId,
    this.observacao = '',
    this.ignorarLimite = false,
  });

  final int etapaId;

  // o veículo ou pet; null no avulso, e aí a identificação é obrigatória
  // (400 avulso_sem_identificacao com os dois vazios)
  final int? objetoId;

  // como reconhecer o avulso no pátio ("Hilux branca", "ABC-1234")
  final String identificacao;
  final int servicoId;
  final DateTime data;
  final Hora? horarioEntrada;

  // quem pega o carro ou o pet; opcional
  final int? colaboradorId;
  final String observacao;

  // o dono recebendo mesmo com o dia lotado (dia_lotado) ou sem vaga na
  // hora (horario_ocupado): para o negócio o limite é aviso
  final bool ignorarLimite;

  bool get ehAvulso => objetoId == null;

  NovoAtendimentoParams copyWith({bool? ignorarLimite}) {
    return NovoAtendimentoParams(
      etapaId: etapaId,
      objetoId: objetoId,
      identificacao: identificacao,
      servicoId: servicoId,
      data: data,
      horarioEntrada: horarioEntrada,
      colaboradorId: colaboradorId,
      observacao: observacao,
      ignorarLimite: ignorarLimite ?? this.ignorarLimite,
    );
  }
}

// o quadro de um dia, inteiro ou só os cards de um profissional
class ListarDoDiaParams {
  const ListarDoDiaParams({required this.data, this.colaboradorId});

  final DateTime data;
  final int? colaboradorId;
}

class MoverAtendimentoParams {
  const MoverAtendimentoParams({required this.id, required this.etapaId});

  final int id;
  final int etapaId;
}

// a grade de horas de entrada de um dia. com o serviço, só as horas em que
// a duração dele cabe (sem ele, a API usa 30 minutos); `excluirId` é o card
// que está sendo remarcado, que a grade não conta como ocupação (senão ele
// barraria a si mesmo)
class SlotsKanbanParams {
  const SlotsKanbanParams({required this.data, this.servicoId, this.excluirId});

  final DateTime data;
  final int? servicoId;
  final int? excluirId;
}

// o ajuste de uma data: o máximo do dia (null é sem máximo) e quantos
// andam ao mesmo tempo, só naquela data
class AjustarCapacidadeParams {
  const AjustarCapacidadeParams({
    required this.data,
    this.capacidade,
    required this.vagas,
  });

  final DateTime data;
  final int? capacidade;
  final int vagas;
}

// remarcar: outro dia e outra hora de entrada (ou sem hora). a capacidade
// do dia de destino é conferida de novo, sem contar o próprio card
class RemarcarAtendimentoKanbanParams {
  const RemarcarAtendimentoKanbanParams({
    required this.id,
    required this.data,
    this.horarioEntrada,
    this.ignorarLimite = false,
  });

  final int id;
  final DateTime data;
  final Hora? horarioEntrada;
  final bool ignorarLimite;
}

// o tempo a mais previsto para o atendimento, em minutos (0 tira). nunca é
// barrado e não mexe no preço
class AjustarTempoParams {
  const AjustarTempoParams({required this.id, required this.minutosExtras});

  final int id;
  final int minutosExtras;
}
