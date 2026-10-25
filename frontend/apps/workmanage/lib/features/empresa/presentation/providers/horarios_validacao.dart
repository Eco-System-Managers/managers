import '../../domain/entities/horario_funcionamento.dart';

// a mensagem embaixo do dia; null quando está tudo certo. a mesma regra no
// onboarding e nas configurações: dia aberto precisa de abertura e
// fechamento, nessa ordem, e na agenda kanban de quantos atendimentos cabem
String? erroDoHorario(HorarioFuncionamento horario, {required bool isKanban}) {
  if (!horario.ativo) return null;

  final abertura = horario.abertura;
  final fechamento = horario.fechamento;
  if (abertura == null || fechamento == null) {
    return 'Informe a abertura e o fechamento';
  }
  if (fechamento.emMinutos <= abertura.emMinutos) {
    return 'O fechamento precisa ser depois da abertura';
  }
  if (isKanban && (horario.capacidade ?? 0) < 1) {
    return 'Informe quantos atendimentos cabem no dia';
  }
  return null;
}

// a mensagem geral do botão de salvar; null quando a semana está válida
String? erroDaSemana(
  List<HorarioFuncionamento> horarios, {
  required bool isKanban,
}) {
  if (!horarios.any((h) => h.ativo)) return 'Abra pelo menos um dia da semana';
  if (horarios.any((h) => erroDoHorario(h, isKanban: isKanban) != null)) {
    return 'Corrija os horários marcados';
  }
  return null;
}
