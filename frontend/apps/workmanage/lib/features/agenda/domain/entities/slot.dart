import 'package:equatable/equatable.dart';
import 'package:managers/core/utils/datas.dart';

// um horário da grade do dia de um profissional para um serviço: livre ou
// ocupado, já descontada a duração do serviço
class Slot extends Equatable {
  const Slot({required this.hora, required this.disponivel});

  final Hora hora;
  final bool disponivel;

  @override
  List<Object?> get props => [hora, disponivel];
}
