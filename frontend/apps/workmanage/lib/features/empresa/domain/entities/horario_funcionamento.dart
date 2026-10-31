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

// marca "não mexa" no copyWith: a capacidade aceita null de verdade
// ("sem máximo"), então null não serve para dizer "mantém"
const _manter = Object();

// um dia da semana do negócio. dia fechado continua existindo, com ativo false
class HorarioFuncionamento {
  const HorarioFuncionamento({
    required this.dia,
    this.ativo = true,
    this.abertura,
    this.fechamento,
    this.capacidade,
    this.vagas = 1,
  });

  final DiaSemana dia;
  final bool ativo;
  final HoraDoDia? abertura;
  final HoraDoDia? fechamento;

  // esteira: o máximo de atendimentos no dia, com ou sem hora. null é sem
  // máximo. no modo agenda não aparece
  final int? capacidade;

  // esteira: quantos atendimentos andam ao mesmo tempo (boxes, banhistas).
  // sempre pelo menos 1
  final int vagas;

  // o step 3 muda um campo por vez (abrir o dia, trocar a hora...)
  HorarioFuncionamento copyWith({
    bool? ativo,
    HoraDoDia? abertura,
    HoraDoDia? fechamento,
    Object? capacidade = _manter,
    int? vagas,
  }) {
    return HorarioFuncionamento(
      dia: dia,
      ativo: ativo ?? this.ativo,
      abertura: abertura ?? this.abertura,
      fechamento: fechamento ?? this.fechamento,
      capacidade: identical(capacidade, _manter)
          ? this.capacidade
          : capacidade as int?,
      vagas: vagas ?? this.vagas,
    );
  }
}
