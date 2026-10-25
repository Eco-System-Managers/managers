import 'package:dio/dio.dart';
import 'package:managers/core/utils/dinheiro.dart';

import '../../domain/entities/dashboard_resumo.dart';

// fala com /dashboard/resumo/ e já devolve a entidade: é leitura pura
abstract class DashboardRemoteDataSource {
  Future<DashboardResumo> resumo();
}

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  DashboardRemoteDataSourceImpl(this.dio);

  final Dio dio;

  @override
  Future<DashboardResumo> resumo() async {
    final response = await dio.get<Map<String, dynamic>>('dashboard/resumo/');
    final json = response.data!;
    final kpis = json['kpis'] as Map<String, dynamic>;
    return DashboardResumo(
      isKanban: json['tipo_agenda'] == 'kanban',
      faturamentoMes: dinheiroDaApi(kpis['faturamento_mes'] as String? ?? '0'),
      faturamentoVariacao: kpis['faturamento_variacao'] as int?,
      atendimentosMes: kpis['atendimentos_mes'] as int? ?? 0,
      atendimentosVariacao: kpis['atendimentos_variacao'] as int?,
      ticketMedio: dinheiroDaApi(kpis['ticket_medio'] as String? ?? '0'),
      clientesNovosMes: kpis['clientes_novos_mes'] as int? ?? 0,
      clientesNovosVariacao: kpis['clientes_novos_variacao'] as int?,
      rankingServicos: [
        for (final r
            in (json['ranking_servicos'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          RankingServico(
            nome: r['nome'] as String? ?? '',
            total: r['total'] as int? ?? 0,
          ),
      ],
      agendamentosHoje: [
        for (final a
            in (json['agendamentos_hoje'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          AgendamentoHoje(
            id: a['id'] as int,
            clienteNome: a['cliente_nome'] as String? ?? '',
            servicoNome: a['servico_nome'] as String? ?? '',
            hora: a['hora'] as String? ?? '',
            status: a['status'] as String? ?? '',
          ),
      ],
    );
  }
}
