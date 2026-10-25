import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

// um atendimento passado que ainda não foi cobrado. vem da agenda ou do
// kanban; o id é do agendamento ou do atendimento, conforme a origem
class PendenciaCobranca extends Equatable {
  const PendenciaCobranca({
    required this.origemAgenda,
    required this.id,
    required this.data,
    required this.clienteId,
    required this.clienteNome,
    required this.servicoNome,
    required this.valor,
  });

  // true: agenda por horário; false: esteira (kanban)
  final bool origemAgenda;
  final int id;
  final DateTime data;
  final int clienteId;
  final String clienteNome;

  // os nomes dos serviços juntos, como a API manda
  final String servicoNome;
  final Decimal valor;

  @override
  List<Object?> get props => [
    origemAgenda,
    id,
    data,
    clienteId,
    clienteNome,
    servicoNome,
    valor,
  ];
}
