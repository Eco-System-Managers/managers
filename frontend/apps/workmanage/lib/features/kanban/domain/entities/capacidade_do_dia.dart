import 'package:equatable/equatable.dart';
import 'package:managers/core/error/failures.dart';

// a API recusou por capacidade: o dia no máximo (dia_lotado) ou sem vaga
// na hora de entrada (horario_ocupado). para o negócio é aviso: a tela
// pergunta e repete com ignorarLimite
bool passaDoLimite(Failure failure) =>
    failure.code == 'dia_lotado' || failure.code == 'horario_ocupado';

// quanto cabe num dia da esteira e quanto já há nele. o padrão vem do dia
// da semana (horários de funcionamento); uma data pode ter um ajuste só
// dela ("hoje somos 2", "hoje sou só eu"), e aí vem ajustado
class CapacidadeDoDia extends Equatable {
  const CapacidadeDoDia({
    required this.data,
    this.capacidade,
    this.vagas = 1,
    this.ajustado = false,
    this.ocupados = 0,
  });

  final DateTime data;

  // o máximo de atendimentos no dia, com ou sem hora; null é sem máximo
  final int? capacidade;

  // quantos atendimentos andam ao mesmo tempo (boxes, banhistas)
  final int vagas;

  // true quando a data tem um ajuste, fora do padrão da semana
  final bool ajustado;

  // os atendimentos do dia, com ou sem hora; quem faltou não conta
  final int ocupados;

  bool get semMaximo => capacidade == null;

  // não cabe mais nenhum pelo máximo do dia (o dono ainda pode ignorar)
  bool get lotado => capacidade != null && ocupados >= capacidade!;

  // o dono recebeu além do máximo
  bool get acimaDoLimite => capacidade != null && ocupados > capacidade!;

  int get excedente => acimaDoLimite ? ocupados - capacidade! : 0;

  // "3 de 8" ou, sem máximo, "3"
  String get ocupacao =>
      capacidade == null ? '$ocupados' : '$ocupados de $capacidade';

  // o resumo do topo do quadro: "3 de 8 hoje · 1 por vez" (sem máximo:
  // "3 hoje · 2 por vez"); acima do máximo: "9 de 8 · 1 acima do limite"
  String textoCurto({bool hoje = true}) {
    if (acimaDoLimite) return '$ocupacao · $excedente acima do limite';
    return '$ocupacao ${hoje ? 'hoje' : 'no dia'} · $vagas por vez';
  }

  @override
  List<Object?> get props => [data, capacidade, vagas, ajustado, ocupados];
}
