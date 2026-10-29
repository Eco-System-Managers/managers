import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/empresa/domain/entities/nicho.dart';
import 'package:managers/features/dashboard/data/datasources/dashboard_remote_datasource.dart';

import '../../helpers/fake_adapter.dart';

const _resumoJson = {
  'tipo_agenda': 'horario',
  'periodo': {
    'data_inicio': '2026-10-19',
    'data_fim': '2026-10-25',
    'anterior_inicio': '2026-10-12',
    'anterior_fim': '2026-10-18',
  },
  'colaborador': 2,
  'kpis': {
    'faturamento': '1500.00',
    'faturamento_variacao': null,
    'atendimentos': 20,
    'atendimentos_variacao': 12,
    'ticket_medio': '75.00',
    'repasse': '600.00',
    'clientes_novos': null,
    'clientes_novos_variacao': null,
  },
  'serie': [
    {'data': '2026-10-19', 'faturamento': '0.00', 'atendimentos': 0},
    {'data': '2026-10-20', 'faturamento': '300.00', 'atendimentos': 4},
  ],
  'ranking_servicos': [
    {'nome': 'Corte', 'nicho': 'cabeleireiro', 'total': 12},
    {'nome': 'Barba', 'nicho': 'barbearia', 'total': 8},
  ],
  'agendamentos_hoje': [
    {
      'id': 3,
      'cliente_nome': 'Ana',
      'cliente_telefone': '11999990000',
      'servico_nome': 'Corte',
      'colaborador_nome': 'Bia',
      'hora': '10:30',
      'status': 'agendado',
    },
  ],
};

void main() {
  test('resumo manda o período e o profissional e lê os números', () async {
    final adapter = FakeAdapter((_) async => respostaJson(200, _resumoJson));
    final datasource = DashboardRemoteDataSourceImpl(dioDeTeste(adapter));

    final resumo = await datasource.resumo(
      inicio: DateTime(2026, 10, 19),
      fim: DateTime(2026, 10, 25),
      colaboradorId: 2,
    );

    final uri = adapter.requisicoes.single.uri;
    expect(uri.path, endsWith('dashboard/resumo/'));
    expect(uri.queryParameters, {
      'data_inicio': '2026-10-19',
      'data_fim': '2026-10-25',
      'colaborador': '2',
    });
    expect(resumo.isKanban, isFalse);
    expect(resumo.intervalo.inicio, DateTime(2026, 10, 19));
    expect(resumo.intervalo.anteriorFim, DateTime(2026, 10, 18));
    expect(resumo.colaboradorId, 2);
    expect(resumo.faturamento, Decimal.parse('1500.00'));
    // sem período anterior para comparar, a variação é nula (não é zero)
    expect(resumo.faturamentoVariacao, isNull);
    expect(resumo.atendimentosVariacao, 12);
    expect(resumo.repasse, Decimal.parse('600.00'));
    // filtrado por profissional, cliente novo não se atribui
    expect(resumo.clientesNovos, isNull);
    expect(resumo.rankingServicos.map((r) => r.nome), ['Corte', 'Barba']);
    expect(resumo.rankingServicos.map((r) => r.nicho), [
      Nicho.cabeleireiro,
      Nicho.barbearia,
    ]);
    expect(resumo.agendamentosHoje.single.hora, '10:30');
    expect(resumo.agendamentosHoje.single.minutos, 10 * 60 + 30);
    expect(resumo.agendamentosHoje.single.id, 3);
    expect(resumo.agendamentosHoje.single.clienteTelefone, '11999990000');
    expect(resumo.agendamentosHoje.single.colaboradorNome, 'Bia');
    expect(resumo.serie.map((p) => p.data), [
      DateTime(2026, 10, 19),
      DateTime(2026, 10, 20),
    ]);
    expect(resumo.serie.last.faturamento, Decimal.parse('300.00'));
    expect(resumo.serie.last.atendimentos, 4);
  });

  test('resumo sem filtros não manda parâmetros: a API usa hoje', () async {
    final adapter = FakeAdapter((_) async => respostaJson(200, _resumoJson));
    final datasource = DashboardRemoteDataSourceImpl(dioDeTeste(adapter));

    await datasource.resumo();

    expect(adapter.requisicoes.single.uri.queryParameters, isEmpty);
  });

  test('para quem não vê valores os kpis de dinheiro vêm nulos', () async {
    final json = {
      ..._resumoJson,
      'kpis': {
        ...(_resumoJson['kpis'] as Map<String, dynamic>),
        'faturamento': null,
        'ticket_medio': null,
        'repasse': null,
      },
    };
    final adapter = FakeAdapter((_) async => respostaJson(200, json));
    final datasource = DashboardRemoteDataSourceImpl(dioDeTeste(adapter));

    final resumo = await datasource.resumo();

    expect(resumo.faturamento, isNull);
    expect(resumo.ticketMedio, isNull);
    expect(resumo.repasse, isNull);
    expect(resumo.atendimentos, 20);
  });
}
