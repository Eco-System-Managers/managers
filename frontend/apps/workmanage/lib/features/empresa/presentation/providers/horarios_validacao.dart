import '../../domain/entities/horario_funcionamento.dart';

// a mensagem embaixo do dia; null quando está tudo certo. a mesma regra no
// onboarding e nas configurações: dia aberto precisa de abertura e
// fechamento, nessa ordem. na esteira, o máximo no dia pode ficar vazio
// (sem máximo), mas quando existe é pelo menos 1, e cabe pelo menos 1 ao
// mesmo tempo
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
  if (isKanban) {
    final capacidade = horario.capacidade;
    if (capacidade != null && capacidade < 1) {
      return 'O máximo no dia é pelo menos 1';
    }
    if (horario.vagas < 1) return 'Cabe pelo menos 1 ao mesmo tempo';
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

// o primeiro dia aberto da semana: é ele que o "Repetir nos outros dias"
// copia. null com a semana toda fechada
HorarioFuncionamento? primeiroDiaAbertoDe(List<HorarioFuncionamento> horarios) {
  for (final h in horarios) {
    if (h.ativo) return h;
  }
  return null;
}

// copia abertura, fechamento, máximo no dia e ao mesmo tempo do primeiro dia
// aberto para os outros, sem mexer no aberto/fechado de cada um: quem tem
// um box só acerta a segunda e repete. sem dia aberto, devolve a lista igual
List<HorarioFuncionamento> repetirPrimeiroDiaAberto(
  List<HorarioFuncionamento> horarios,
) {
  final modelo = primeiroDiaAbertoDe(horarios);
  if (modelo == null) return horarios;
  return [
    for (final h in horarios)
      h.dia == modelo.dia
          ? h
          : h.copyWith(
              abertura: modelo.abertura,
              fechamento: modelo.fechamento,
              capacidade: modelo.capacidade,
              vagas: modelo.vagas,
            ),
  ];
}
