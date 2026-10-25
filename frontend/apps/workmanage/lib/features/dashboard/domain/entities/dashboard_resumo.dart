import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

// os números do mês e o dia de hoje, como a API agrega (dashboard/resumo/)
class DashboardResumo extends Equatable {
  const DashboardResumo({
    required this.isKanban,
    required this.faturamentoMes,
    required this.faturamentoVariacao,
    required this.atendimentosMes,
    required this.atendimentosVariacao,
    required this.ticketMedio,
    required this.clientesNovosMes,
    required this.clientesNovosVariacao,
    required this.rankingServicos,
    required this.agendamentosHoje,
  });

  final bool isKanban;
  final Decimal faturamentoMes;

  // variação % sobre o mês anterior; null sem base de comparação (a tela
  // não mostra "+∞%" no primeiro mês)
  final int? faturamentoVariacao;
  final int atendimentosMes;
  final int? atendimentosVariacao;
  final Decimal ticketMedio;
  final int clientesNovosMes;
  final int? clientesNovosVariacao;

  // top 5 do mês
  final List<RankingServico> rankingServicos;

  // até 10 do dia
  final List<AgendamentoHoje> agendamentosHoje;

  @override
  List<Object?> get props => [
    isKanban,
    faturamentoMes,
    faturamentoVariacao,
    atendimentosMes,
    atendimentosVariacao,
    ticketMedio,
    clientesNovosMes,
    clientesNovosVariacao,
    rankingServicos,
    agendamentosHoje,
  ];
}

class RankingServico extends Equatable {
  const RankingServico({required this.nome, required this.total});

  final String nome;
  final int total;

  @override
  List<Object?> get props => [nome, total];
}

class AgendamentoHoje extends Equatable {
  const AgendamentoHoje({
    required this.id,
    required this.clienteNome,
    required this.servicoNome,
    required this.hora,
    required this.status,
  });

  final int id;
  final String clienteNome;
  final String servicoNome;

  // "HH:MM"
  final String hora;
  final String status;

  @override
  List<Object?> get props => [id, clienteNome, servicoNome, hora, status];
}
