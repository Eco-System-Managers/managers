import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/dashboard/data/datasources/dashboard_remote_datasource.dart';

import '../../helpers/fake_adapter.dart';

void main() {
  test('resumo lê os números do mês, o ranking e o dia de hoje', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, {
        'tipo_agenda': 'horario',
        'kpis': {
          'faturamento_mes': '1500.00',
          'faturamento_variacao': null,
          'atendimentos_mes': 20,
          'atendimentos_variacao': 12,
          'ticket_medio': '75.00',
          'clientes_novos_mes': 3,
          'clientes_novos_variacao': -50,
        },
        'ranking_servicos': [
          {'nome': 'Corte', 'total': 12},
          {'nome': 'Barba', 'total': 8},
        ],
        'agendamentos_hoje': [
          {
            'id': 3,
            'cliente_nome': 'Ana',
            'servico_nome': 'Corte',
            'hora': '10:30',
            'status': 'agendado',
          },
        ],
        'faturamento_30d': <Object>[],
        'atendimentos_30d': <Object>[],
      }),
    );
    final datasource = DashboardRemoteDataSourceImpl(dioDeTeste(adapter));

    final resumo = await datasource.resumo();

    expect(adapter.requisicoes.single.path, 'dashboard/resumo/');
    expect(resumo.isKanban, isFalse);
    expect(resumo.faturamentoMes, Decimal.parse('1500.00'));
    // sem mês anterior para comparar, a variação é nula (não é zero)
    expect(resumo.faturamentoVariacao, isNull);
    expect(resumo.atendimentosVariacao, 12);
    expect(resumo.clientesNovosVariacao, -50);
    expect(resumo.rankingServicos.map((r) => r.nome), ['Corte', 'Barba']);
    expect(resumo.agendamentosHoje.single.hora, '10:30');
    expect(resumo.agendamentosHoje.single.id, 3);
  });
}
