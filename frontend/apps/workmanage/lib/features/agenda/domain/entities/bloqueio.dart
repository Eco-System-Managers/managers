import 'package:equatable/equatable.dart';
import 'package:managers/core/utils/datas.dart';

// um período em que o profissional não atende: um imprevisto, uma folga, as
// férias ou a pausa de todo dia (o almoço). tira o trecho da grade, para a
// empresa e para o app do cliente
class Bloqueio extends Equatable {
  const Bloqueio({
    required this.id,
    required this.colaboradorId,
    required this.colaboradorNome,
    required this.dataInicio,
    this.dataFim,
    this.horaInicio,
    this.horaFim,
    this.motivo = '',
  });

  final int id;
  final int colaboradorId;
  final String colaboradorNome;
  final DateTime dataInicio;

  // null: fixo, vale todos os dias a partir do início
  final DateTime? dataFim;

  // as duas null: o dia inteiro
  final Hora? horaInicio;
  final Hora? horaFim;
  final String motivo;

  bool get fixo => dataFim == null;
  bool get diaInteiro => horaInicio == null || horaFim == null;

  @override
  List<Object?> get props => [
    id,
    colaboradorId,
    colaboradorNome,
    dataInicio,
    dataFim,
    horaInicio,
    horaFim,
    motivo,
  ];
}

// os períodos que a tela oferece. a API só guarda o fim: eles viram dataFim
enum PeriodoDoBloqueio { umDia, umaSemana, umMes, fixo }

// o último dia do período, contando o início. null é o fixo
DateTime? fimDoPeriodo(PeriodoDoBloqueio periodo, DateTime inicio) {
  return switch (periodo) {
    PeriodoDoBloqueio.umDia => inicio,
    PeriodoDoBloqueio.umaSemana => DateTime(
      inicio.year,
      inicio.month,
      inicio.day + 6,
    ),
    // de 10/11 a 09/12
    PeriodoDoBloqueio.umMes => DateTime(
      inicio.year,
      inicio.month + 1,
      inicio.day - 1,
    ),
    PeriodoDoBloqueio.fixo => null,
  };
}
