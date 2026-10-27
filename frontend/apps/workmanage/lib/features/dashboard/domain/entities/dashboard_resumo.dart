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
    this.repasse,
    required this.clientesNovos,
    required this.clientesNovosVariacao,
    this.serie = const [],
    required this.rankingServicos,
    required this.agendamentosHoje,
  });

  final bool isKanban;
  final IntervaloResumo intervalo;

  // o profissional aplicado pela API: o pedido, ou o próprio de quem não é
  // proprietário (a trava é do backend)
  final int? colaboradorId;

  // null para o colaborador comum, que não vê valores (idem ticketMedio e
  // repasse)
  final Decimal? faturamento;

  // variação % sobre o período anterior; null sem base de comparação (a tela
  // não mostra "+∞%" no primeiro dia)
  final int? faturamentoVariacao;
  final int atendimentos;
  final int? atendimentosVariacao;
  final Decimal? ticketMedio;

  // a parte dos parceiros no período; para o parceiro, o que ele tem a
  // receber
  final Decimal? repasse;

  // null quando filtrado por profissional: cliente novo é do negócio
  final int? clientesNovos;
  final int? clientesNovosVariacao;

  // um ponto por dia do período, com os critérios dos kpis: o gráfico
  final List<PontoDaSerie> serie;

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
    repasse,
    clientesNovos,
    clientesNovosVariacao,
    serie,
    rankingServicos,
    agendamentosHoje,
  ];
}

// o faturamento e os atendimentos de um dia do período
class PontoDaSerie extends Equatable {
  const PontoDaSerie({
    required this.data,
    required this.faturamento,
    required this.atendimentos,
  });

  final DateTime data;

  // null para quem não vê valores
  final Decimal? faturamento;
  final int atendimentos;

  @override
  List<Object?> get props => [data, faturamento, atendimentos];
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
    this.clienteTelefone = '',
    required this.servicoNome,
    this.colaboradorNome = '',
    required this.hora,
    required this.status,
  });

  final int id;
  final String clienteNome;

  // só dígitos, para o WhatsApp
  final String clienteTelefone;
  final String servicoNome;

  // vazio sem profissional (a esteira)
  final String colaboradorNome;

  // "HH:MM"
  final String hora;
  final String status;

  // a hora como minutos desde a meia-noite, para ordenar e comparar
  int get minutos {
    final partes = hora.split(':');
    if (partes.length != 2) return 0;
    return (int.tryParse(partes[0]) ?? 0) * 60 + (int.tryParse(partes[1]) ?? 0);
  }

  @override
  List<Object?> get props => [
    id,
    clienteNome,
    clienteTelefone,
    servicoNome,
    colaboradorNome,
    hora,
    status,
  ];
}
