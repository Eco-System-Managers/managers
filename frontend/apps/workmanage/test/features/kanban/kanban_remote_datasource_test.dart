import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/financeiro/domain/entities/pagamento.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';
import 'package:managers/features/kanban/data/datasources/kanban_remote_datasource.dart';
import 'package:managers/features/kanban/data/models/kanban_models.dart';
import 'package:managers/features/kanban/domain/entities/etapa.dart';
import 'package:managers/features/kanban/domain/params/kanban_params.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> _etapaJson(int id, String nome, int ordem) => {
  'id': id,
  'nome': nome,
  'ordem': ordem,
  'cor': '#F59E0B',
};

Map<String, dynamic> _atendimentoJson(
  int id, {
  bool pago = false,
  String tipo = 'veiculo',
  String? hora = '09:30:00',
}) => {
  'id': id,
  'etapa': 1,
  'etapa_nome': 'Aguardando',
  'objeto': 10,
  'objeto_detalhe': {
    'id': 10,
    'tipo': tipo,
    'criado_em': '2026-10-20T10:00:00-03:00',
    'detalhe': tipo == 'veiculo'
        ? {
            'id': 10,
            'cliente': 7,
            'placa': 'ABC1D23',
            'marca': 'Fiat',
            'modelo': 'Uno',
            'cor': 'Prata',
            'criado_em': '2026-10-20T10:00:00-03:00',
          }
        : {
            'id': 10,
            'cliente': 7,
            'nome': 'Rex',
            'especie': 'Cachorro',
            'raca': '',
            'porte': 'medio',
            'data_nascimento': null,
            'criado_em': '2026-10-20T10:00:00-03:00',
          },
  },
  'cliente_nome': 'Ana',
  'cliente_telefone': '19999990000',
  'servico': 3,
  'servico_nome': 'Lavagem',
  'servico_preco': '60.00',
  'servico_duracao': 40,
  'observacao': '',
  'data': '2026-10-25',
  'horario_entrada': hora,
  'pago': pago,
  'faltou': false,
  'desconto': '0.00',
  'pagamentos': pago
      ? [
          {'id': 1, 'forma': 'pix', 'valor': '60.00'},
        ]
      : <Object>[],
  'criado_em': '2026-10-25T09:00:00-03:00',
};

Map<String, dynamic> _pagina(List<Map<String, dynamic>> results) => {
  'count': results.length,
  'next': null,
  'previous': null,
  'results': results,
};

void main() {
  test('listarEtapas segue a paginação e converte', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, _pagina([_etapaJson(2, 'Lavando', 1)])),
    );
    final datasource = KanbanRemoteDataSourceImpl(dioDeTeste(adapter));

    final etapas = await datasource.listarEtapas();

    final uri = adapter.requisicoes.single.uri;
    expect(uri.path, endsWith('kanban/etapas/'));
    expect(uri.queryParameters['page_size'], '100');
    expect(
      etapas.single.toEntity(),
      const Etapa(id: 2, nome: 'Lavando', ordem: 1, cor: '#F59E0B'),
    );
  });

  test(
    'etapa nova é POST e existente é PATCH; reordenar manda os ids',
    () async {
      final adapter = FakeAdapter((options) async {
        if (options.path.endsWith('reordenar/')) return respostaJson(204, null);
        return respostaJson(200, _etapaJson(5, 'Secando', 2));
      });
      final datasource = KanbanRemoteDataSourceImpl(dioDeTeste(adapter));

      await datasource.criarEtapa(
        const Etapa(nome: 'Secando', ordem: 2, cor: '#3B82F6'),
      );
      await datasource.atualizarEtapa(
        const Etapa(id: 5, nome: 'Secagem', ordem: 2),
      );
      await datasource.reordenarEtapas([3, 1, 2]);
      await datasource.removerEtapa(5);

      expect(adapter.requisicoes.map((r) => '${r.method} ${r.path}'), [
        'POST kanban/etapas/',
        'PATCH kanban/etapas/5/',
        'POST kanban/etapas/reordenar/',
        'DELETE kanban/etapas/5/',
      ]);
      expect(adapter.requisicoes[0].data, {
        'nome': 'Secando',
        'ordem': 2,
        'cor': '#3B82F6',
      });
      expect(adapter.requisicoes[2].data, {
        'ordem': [3, 1, 2],
      });
    },
  );

  test(
    'listarDoDia manda o dia e page_size 100; o model converte o card',
    () async {
      final adapter = FakeAdapter(
        (_) async =>
            respostaJson(200, _pagina([_atendimentoJson(1, pago: true)])),
      );
      final datasource = KanbanRemoteDataSourceImpl(dioDeTeste(adapter));

      final lista = await datasource.listarDoDia(DateTime(2026, 10, 25));

      expect(adapter.requisicoes.single.uri.queryParameters, {
        'data': '2026-10-25',
        'page_size': '100',
      });
      final a = lista.single.toEntity();
      expect(a.etapaNome, 'Aguardando');
      expect(a.objeto.veiculo?.placa, 'ABC1D23');
      expect(a.objeto.titulo, 'Fiat Uno');
      expect(a.clienteId, 7);
      expect(a.horarioEntrada, (hora: 9, minuto: 30));
      expect(a.data, DateTime(2026, 10, 25));
      expect(a.servicoPreco, Decimal.parse('60.00'));
      expect(a.valorTotal, Decimal.parse('60.00'));
      expect(a.pago, isTrue);
      expect(a.pagamentos.single.forma, FormaPagamento.pix);
    },
  );

  test('o model lê um pet e um card sem hora', () {
    final a = AtendimentoKanbanModel.fromJson(
      _atendimentoJson(2, tipo: 'pet', hora: null),
    ).toEntity();

    expect(a.objeto.pet?.nome, 'Rex');
    expect(a.objeto.detalhe, 'Cachorro · Médio');
    expect(a.horarioEntrada, isNull);
  });

  test('criar manda o corpo do contrato, com e sem hora de entrada', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(201, _atendimentoJson(9)),
    );
    final datasource = KanbanRemoteDataSourceImpl(dioDeTeste(adapter));

    await datasource.criar(
      NovoAtendimentoParams(
        etapaId: 1,
        objetoId: 10,
        servicoId: 3,
        data: DateTime(2026, 10, 25),
        horarioEntrada: (hora: 9, minuto: 30),
        observacao: 'Chaves no painel',
      ),
    );
    await datasource.criar(
      NovoAtendimentoParams(
        etapaId: 1,
        objetoId: 10,
        servicoId: 3,
        data: DateTime(2026, 10, 25),
        colaboradorId: 2,
      ),
    );

    expect(adapter.requisicoes[0].path, 'kanban/atendimentos/');
    expect(adapter.requisicoes[0].data, {
      'etapa': 1,
      'objeto': 10,
      'servico': 3,
      'data': '2026-10-25',
      'horario_entrada': '09:30',
      'observacao': 'Chaves no painel',
    });
    expect((adapter.requisicoes[1].data as Map)['horario_entrada'], isNull);
    // o profissional só vai quando escolhido
    expect(
      (adapter.requisicoes[0].data as Map).containsKey('colaborador'),
      isFalse,
    );
    expect((adapter.requisicoes[1].data as Map)['colaborador'], 2);
  });

  test(
    'as ações do card são POST em kanban/atendimentos/{id}/<acao>/',
    () async {
      final adapter = FakeAdapter((options) async {
        if (options.method == 'DELETE') return respostaJson(204, null);
        return respostaJson(200, _atendimentoJson(3));
      });
      final datasource = KanbanRemoteDataSourceImpl(dioDeTeste(adapter));

      await datasource.mover(3, 2);
      await datasource.cobrar(
        CobrancaParams(
          id: 3,
          pagamentos: [
            Pagamento(
              forma: FormaPagamento.dinheiro,
              valor: Decimal.fromInt(60),
            ),
          ],
        ),
      );
      await datasource.desfazerCobranca(3);
      await datasource.marcarFalta(3);
      await datasource.desfazerFalta(3);
      await datasource.remover(3);

      expect(adapter.requisicoes.map((r) => '${r.method} ${r.path}'), [
        'POST kanban/atendimentos/3/mover/',
        'POST kanban/atendimentos/3/cobrar/',
        'POST kanban/atendimentos/3/desfazer_cobranca/',
        'POST kanban/atendimentos/3/marcar_falta/',
        'POST kanban/atendimentos/3/desfazer_falta/',
        'DELETE kanban/atendimentos/3/',
      ]);
      expect(adapter.requisicoes[0].data, {'etapa_id': 2});
      expect(adapter.requisicoes[1].data, {
        'desconto': '0.00',
        'pagamentos': [
          {'forma': 'dinheiro', 'valor': '60.00'},
        ],
        'credito_aplicado': '0.00',
        'troco_credito': '0.00',
      });
    },
  );

  test('slots manda o dia e fica só com as horas livres', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, [
        {'horario': '09:00', 'disponivel': true},
        {'horario': '09:30', 'disponivel': false},
        {'horario': '10:30', 'disponivel': true},
      ]),
    );
    final datasource = KanbanRemoteDataSourceImpl(dioDeTeste(adapter));

    final horas = await datasource.slots(DateTime(2026, 10, 25));

    expect(adapter.requisicoes.single.uri.path, endsWith('kanban/slots/'));
    expect(adapter.requisicoes.single.uri.queryParameters, {
      'data': '2026-10-25',
    });
    expect(horas, [(hora: 9, minuto: 0), (hora: 10, minuto: 30)]);
  });

  test('listarDoCliente filtra pelo cliente', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, _pagina([_atendimentoJson(1)])),
    );
    final datasource = KanbanRemoteDataSourceImpl(dioDeTeste(adapter));

    await datasource.listarDoCliente(7);

    expect(adapter.requisicoes.single.uri.queryParameters, {
      'cliente': '7',
      'page_size': '100',
    });
  });
}
