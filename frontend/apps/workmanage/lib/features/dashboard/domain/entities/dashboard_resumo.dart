import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

// os números de um período, comparados com o anterior de mesmo tamanho, como
// a API agrega (dashboard/resumo/)
class DashboardResumo extends Equatable {
  const DashboardResumo({
    required this.isKanban,
    required this.intervalo,
    required this.colaboradorId,
    required this.faturamento,
    required this.faturamentoVariacao,
    required this.atendimentos,
    required this.atendimentosVariacao,
    required this.ticketMedio,
    required this.clientesNovos,
    required this.clientesNovosVariacao,
    required this.rankingServicos,
    required this.agendamentosHoje,
  });

  final bool isKanban;
  final IntervaloResumo intervalo;

  // o profissional aplicado pela API: o pedido, ou o próprio de quem não é
  // proprietário (a trava é do backend)
  final int? colaboradorId;

  final Decimal faturamento;

  // variação % sobre o período anterior; null sem base de comparação (a tela
  // não mostra "+∞%" no primeiro dia)
  final int? faturamentoVariacao;
  final int atendimentos;
  final int? atendimentosVariacao;
  final Decimal ticketMedio;

  // null quando filtrado por profissional: cliente novo é do negócio
  final int? clientesNovos;
  final int? clientesNovosVariacao;

  // top 5 do período
  final List<RankingServico> rankingServicos;

  // até 10 do dia de hoje, independente do período
  final List<AgendamentoHoje> agendamentosHoje;

  @override
  List<Object?> get props => [
    isKanban,
    intervalo,
    colaboradorId,
    faturamento,
    faturamentoVariacao,
    atendimentos,
    atendimentosVariacao,
    ticketMedio,
    clientesNovos,
    clientesNovosVariacao,
    rankingServicos,
    agendamentosHoje,
  ];
}

// o período aplicado e o de comparação (mesmo tamanho, termina na véspera)
class IntervaloResumo extends Equatable {
  const IntervaloResumo({
    required this.inicio,
    required this.fim,
    required this.anteriorInicio,
    required this.anteriorFim,
  });

  final DateTime inicio;
  final DateTime fim;
  final DateTime anteriorInicio;
  final DateTime anteriorFim;

  @override
  List<Object?> get props => [inicio, fim, anteriorInicio, anteriorFim];
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
