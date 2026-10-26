import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/financeiro/data/datasources/financeiro_remote_datasource.dart';

import '../../helpers/fake_adapter.dart';

final _caixaJson = {
  'kpis': {
    'total': '150.00',
    'ticket_medio': '75.00',
    'atendimentos': 2,
    'repasse': '60.00',
    'casa': '90.00',
  },
  'por_forma': [
    {'forma': 'pix', 'total': '100.00', 'percentual': 67},
    {'forma': 'dinheiro', 'total': '50.00', 'percentual': 33},
  ],
  'pagamentos': [
    {
      'origem': 'agenda',
      'cliente_nome': 'Ana',
      'servico_nome': 'Corte',
      'colaborador_nome': 'Bia',
      'forma': 'pix',
      'valor': '100.00',
      'data_hora': '2026-10-25T10:30:00-03:00',
    },
  ],
};

void main() {
  test('caixa manda o período e o profissional e lê os números', () async {
    final adapter = FakeAdapter((_) async => respostaJson(200, _caixaJson));
    final datasource = FinanceiroRemoteDataSourceImpl(dioDeTeste(adapter));

    final caixa = await datasource.caixa(
      inicio: DateTime(2026, 10, 1),
      fim: DateTime(2026, 10, 25),
      colaboradorId: 2,
    );

    final uri = adapter.requisicoes.single.uri;
    expect(uri.path, endsWith('financeiro/caixa/'));
    expect(uri.queryParameters, {
      'data_inicio': '2026-10-01',
      'data_fim': '2026-10-25',
      'colaborador': '2',
    });
    expect(caixa.total, Decimal.parse('150.00'));
    expect(caixa.ticketMedio, Decimal.parse('75.00'));
    expect(caixa.atendimentos, 2);
    expect(caixa.repasse, Decimal.parse('60.00'));
    expect(caixa.casa, Decimal.parse('90.00'));
    expect(caixa.porForma.map((f) => f.forma), ['pix', 'dinheiro']);
    expect(caixa.porForma.first.percentual, 67);
    final pagamento = caixa.pagamentos.single;
    expect(pagamento.origemAgenda, isTrue);
    expect(pagamento.colaboradorNome, 'Bia');
    expect(pagamento.valor, Decimal.parse('100.00'));
    expect(pagamento.dataHora.toUtc(), DateTime.utc(2026, 10, 25, 13, 30));
  });

  test('caixa sem datas não manda filtro: a API usa hoje', () async {
    final adapter = FakeAdapter((_) async => respostaJson(200, _caixaJson));
    final datasource = FinanceiroRemoteDataSourceImpl(dioDeTeste(adapter));

    await datasource.caixa();

    expect(adapter.requisicoes.single.uri.queryParameters, isEmpty);
  });

  test('saldoDoCliente lê o saldo e o extrato', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, {
        'saldo': '12.50',
        'transacoes': [
          {
            'id': 1,
            'tipo': 'credito',
            'valor': '15.00',
            'origem': 'troco',
            'descricao': '',
            'atendimento_kanban': null,
            'agendamento': 3,
            'criado_em': '2026-10-20T10:00:00-03:00',
          },
          {
            'id': 2,
            'tipo': 'debito',
            'valor': '2.50',
            'origem': 'desconto_aplicado',
            'descricao': '',
            'atendimento_kanban': null,
            'agendamento': 4,
            'criado_em': '2026-10-21T10:00:00-03:00',
          },
        ],
      }),
    );
    final datasource = FinanceiroRemoteDataSourceImpl(dioDeTeste(adapter));

    final saldo = await datasource.saldoDoCliente(7);

    expect(adapter.requisicoes.single.path, 'financeiro/clientes/7/saldo/');
    expect(saldo.saldo, Decimal.parse('12.50'));
    expect(saldo.transacoes, hasLength(2));
    expect(saldo.transacoes.first.credito, isTrue);
    expect(saldo.transacoes.first.origemNome, 'Troco de atendimento');
    expect(saldo.transacoes.last.credito, isFalse);
    expect(saldo.transacoes.last.valor, Decimal.parse('2.50'));
  });
}
