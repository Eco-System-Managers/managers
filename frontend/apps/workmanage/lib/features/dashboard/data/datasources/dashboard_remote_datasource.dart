import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';

import '../../domain/entities/dashboard_resumo.dart';

// fala com /dashboard/resumo/ e já devolve a entidade: é leitura pura
abstract class DashboardRemoteDataSource {
  Future<DashboardResumo> resumo({
    DateTime? inicio,
    DateTime? fim,
    int? colaboradorId,
  });
}

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  DashboardRemoteDataSourceImpl(this.dio);

  final Dio dio;

  @override
  Future<DashboardResumo> resumo({
    DateTime? inicio,
    DateTime? fim,
    int? colaboradorId,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      'dashboard/resumo/',
      queryParameters: {
        if (inicio != null) 'data_inicio': dataParaApi(inicio),
        if (fim != null) 'data_fim': dataParaApi(fim),
        'colaborador': ?colaboradorId,
      },
    );
    final json = response.data!;
    final kpis = json['kpis'] as Map<String, dynamic>;
    final periodo = json['periodo'] as Map<String, dynamic>;
    return DashboardResumo(
      isKanban: json['tipo_agenda'] == 'kanban',
      intervalo: IntervaloResumo(
        inicio: dataDaApi(periodo['data_inicio'] as String),
        fim: dataDaApi(periodo['data_fim'] as String),
        anteriorInicio: dataDaApi(periodo['anterior_inicio'] as String),
        anteriorFim: dataDaApi(periodo['anterior_fim'] as String),
      ),
      colaboradorId: json['colaborador'] as int?,
      faturamento: _dinheiroOuNulo(kpis['faturamento']),
      faturamentoVariacao: kpis['faturamento_variacao'] as int?,
      atendimentos: kpis['atendimentos'] as int? ?? 0,
      atendimentosVariacao: kpis['atendimentos_variacao'] as int?,
      ticketMedio: _dinheiroOuNulo(kpis['ticket_medio']),
      repasse: _dinheiroOuNulo(kpis['repasse']),
      clientesNovos: kpis['clientes_novos'] as int?,
      clientesNovosVariacao: kpis['clientes_novos_variacao'] as int?,
      serie: [
        for (final p
            in (json['serie'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          PontoDaSerie(
            data: dataDaApi(p['data'] as String),
            faturamento: _dinheiroOuNulo(p['faturamento']),
            atendimentos: p['atendimentos'] as int? ?? 0,
          ),
      ],
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
            clienteTelefone: a['cliente_telefone'] as String? ?? '',
            servicoNome: a['servico_nome'] as String? ?? '',
            colaboradorNome: a['colaborador_nome'] as String? ?? '',
            hora: a['hora'] as String? ?? '',
            status: a['status'] as String? ?? '',
          ),
      ],
    );
  }
}

// os kpis de dinheiro vêm nulos para quem não vê valores
Decimal? _dinheiroOuNulo(Object? valor) =>
    valor == null ? null : dinheiroDaApi(valor as String);
