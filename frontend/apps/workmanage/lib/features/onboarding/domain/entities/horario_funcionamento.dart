// a ordem é a do backend: o index vai de 0 (segunda) a 6 (domingo),
// diferente do DateTime.weekday do Dart, que vai de 1 (segunda) a 7
enum DiaSemana { segunda, terca, quarta, quinta, sexta, sabado, domingo }

// um horário do dia, sem data. o TimeOfDay do Flutter faria isso, mas o
// domain é Dart puro
class HoraDoDia {
  const HoraDoDia(this.hora, this.minuto);

  final int hora;
  final int minuto;

  // facilita comparar: fechamento precisa ser depois da abertura
  int get emMinutos => hora * 60 + minuto;
}

// um dia da semana do negócio. dia fechado continua existindo, com ativo false
class HorarioFuncionamento {
  const HorarioFuncionamento({
    required this.dia,
    this.ativo = true,
    this.abertura,
    this.fechamento,
    this.capacidade,
  });

  final DiaSemana dia;
  final bool ativo;
  final HoraDoDia? abertura;
  final HoraDoDia? fechamento;

  // atendimentos por dia; só existe para nicho de agenda kanban
  final int? capacidade;
}
