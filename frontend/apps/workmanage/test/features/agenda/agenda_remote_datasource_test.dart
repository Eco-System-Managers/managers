import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/agenda/data/datasources/agenda_remote_datasource.dart';
import 'package:managers/features/agenda/data/models/agendamento_model.dart';
import 'package:managers/features/agenda/domain/entities/agendamento.dart';
import 'package:managers/features/agenda/domain/params/agenda_params.dart';
import 'package:managers/features/financeiro/domain/entities/pagamento.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> _agendamentoJson(
  int id, {
  String status = 'agendado',
  String acrescimo = '0.00',
}) => {
  'id': id,
  'cliente': 7,
  'cliente_nome': 'Ana Silva',
  'cliente_telefone': '19999990000',
  'colaborador': 2,
  'colaborador_nome': 'Bia',
  'data_hora': '2026-10-25T10:30:00-03:00',
  'status': status,
  'desconto': '0.00',
  'acrescimo': acrescimo,
  'acrescimo_motivo': acrescimo == '0.00' ? '' : 'Serviço extra',
  'observacoes': 'Sem máquina',
  'criado_em': '2026-10-20T10:00:00-03:00',
  'servicos': [
    {
      'id': 11,
      'agendamento': id,
      'servico': 3,
      'servico_nome': 'Corte',
      'servico_duracao': 30,
      'preco_cobrado': '45.50',
      'desconto': '0.00',
    },
  ],
  'pagamentos': [
    {'id': 1, 'forma': 'pix', 'valor': '45.50'},
  ],
};

Map<String, dynamic> _pagina(
  List<Map<String, dynamic>> results, {
  String? next,
}) => {
  'count': results.length,
  'next': next,
  'previous': null,
  'results': results,
};

void main() {
  test(
    'listarDoDia manda o dia, o profissional e page_size 100, e segue o next',
    () async {
      final adapter = FakeAdapter((options) async {
        if (options.uri.queryParameters['page'] == '2') {
          return respostaJson(200, _pagina([_agendamentoJson(2)]));
        }
        return respostaJson(
          200,
          _pagina(
            [_agendamentoJson(1)],
            next: 'http://api.teste/api/v1/agendamentos/?data=2026-10-25&page=2&page_size=100',
          ),
        );
      });
      final datasource = AgendaRemoteDataSourceImpl(dioDeTeste(adapter));

      final lista = await datasource.listarDoDia(
        DateTime(2026, 10, 25),
        colaboradorId: 2,
      );

      expect(lista.map((m) => m.toEntity().id), [1, 2]);
      final primeira = adapter.requisicoes.first.uri;
      expect(primeira.path, endsWith('agendamentos/'));
      expect(primeira.queryParameters, {
        'data': '2026-10-25',
        'colaborador': '2',
        'page_size': '100',
      });
      expect(adapter.requisicoes, hasLength(2));
    },
  );

  test('listarDoCliente manda o cliente e page_size 100', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, _pagina([_agendamentoJson(1)])),
    );
    final datasource = AgendaRemoteDataSourceImpl(dioDeTeste(adapter));

    final lista = await datasource.listarDoCliente(7);

    expect(lista.map((m) => m.toEntity().id), [1]);
    expect(adapter.requisicoes.single.uri.queryParameters, {
      'cliente': '7',
      'page_size': '100',
    });
  });

  test('o model converte data/hora, status, serviços e pagamentos', () {
    final a = AgendamentoModel.fromJson(
      _agendamentoJson(1, status: 'concluido'),
    ).toEntity();

    expect(a.dataHora.toUtc(), DateTime.utc(2026, 10, 25, 13, 30));
    expect(a.status, StatusAgendamento.concluido);
    expect(a.duracaoTotal, 30);
    expect(a.fim.difference(a.dataHora), const Duration(minutes: 30));
    expect(a.valorTotal, Decimal.parse('45.50'));
    expect(a.pagamentos.single.forma, FormaPagamento.pix);
    expect(a.pago, isTrue);
    expect(a.aberto, isFalse);
    expect(a.colaboradorNome, 'Bia');
  });

  test('o model lê o acréscimo e o soma no total', () {
    final a = AgendamentoModel.fromJson(_agendamentoJson(1, acrescimo: '10.00'))
        .toEntity();

    expect(a.acrescimo, Decimal.parse('10.00'));
    expect(a.acrescimoMotivo, 'Serviço extra');
    expect(a.valorTotal, Decimal.parse('55.50'));
  });

  test(
    'criar manda o JSON do contrato, com servico_id e a data com fuso',
    () async {
      final adapter = FakeAdapter(
        (_) async => respostaJson(201, _agendamentoJson(9)),
      );
      final datasource = AgendaRemoteDataSourceImpl(dioDeTeste(adapter));

      final criado = await datasource.criar(
        NovoAgendamentoParams(
          clienteId: 7,
          servicoId: 3,
          colaboradorId: 2,
          dataHora: DateTime(2026, 10, 25, 10, 30),
          observacoes: 'Sem máquina',
        ),
      );

      final requisicao = adapter.requisicoes.single;
      expect(requisicao.method, 'POST');
      expect(requisicao.path, 'agendamentos/');
      final corpo = requisicao.data as Map<String, dynamic>;
      expect(corpo['cliente'], 7);
      expect(corpo['servico_id'], 3);
      expect(corpo['colaborador'], 2);
      expect(corpo['observacoes'], 'Sem máquina');
      expect(
        corpo['data_hora'],
        matches(RegExp(r'^2026-10-25T10:30:00[+-]\d\d:\d\d$')),
      );
      expect(criado.toEntity().id, 9);
    },
  );

  test('atualizar faz PATCH no id só com os campos dados', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, _agendamentoJson(3, status: 'confirmado')),
    );
    final datasource = AgendaRemoteDataSourceImpl(dioDeTeste(adapter));

    final atualizado = await datasource.atualizar(3, {'status': 'confirmado'});

    final requisicao = adapter.requisicoes.single;
    expect(requisicao.method, 'PATCH');
    expect(requisicao.path, 'agendamentos/3/');
    expect(requisicao.data, {'status': 'confirmado'});
    expect(atualizado.toEntity().status, StatusAgendamento.confirmado);
  });

  test('cobrar manda o corpo da cobrança para a ação cobrar', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, _agendamentoJson(3, status: 'concluido')),
    );
    final datasource = AgendaRemoteDataSourceImpl(dioDeTeste(adapter));

    await datasource.cobrar(
      CobrancaParams(
        id: 3,
        pagamentos: [
          Pagamento(
            forma: FormaPagamento.qrCode,
            valor: Decimal.parse('40.50'),
          ),
          Pagamento(forma: FormaPagamento.dinheiro, valor: Decimal.fromInt(5)),
        ],
        trocoCredito: Decimal.parse('2.00'),
      ),
    );

    final requisicao = adapter.requisicoes.single;
    expect(requisicao.method, 'POST');
    expect(requisicao.path, 'agendamentos/3/cobrar/');
    expect(requisicao.data, {
      'desconto': '0.00',
      'acrescimo': '0.00',
      'acrescimo_motivo': '',
      'pagamentos': [
        {'forma': 'qr_code', 'valor': '40.50'},
        {'forma': 'dinheiro', 'valor': '5.00'},
      ],
      'credito_aplicado': '0.00',
      'troco_credito': '2.00',
    });
  });

  test('slots manda dia, serviço e profissional e lê a grade', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, [
        {'horario': '09:00', 'disponivel': true},
        {'horario': '09:30', 'disponivel': false},
      ]),
    );
    final datasource = AgendaRemoteDataSourceImpl(dioDeTeste(adapter));

    final slots = await datasource.slots(
      SlotsParams(data: DateTime(2026, 10, 25), servicoId: 3, colaboradorId: 2),
    );

    final uri = adapter.requisicoes.single.uri;
    expect(uri.path, endsWith('agenda/slots/'));
    expect(uri.queryParameters, {
      'data': '2026-10-25',
      'servico': '3',
      'colaborador': '2',
    });
    expect(slots.map((s) => s.hora), [
      (hora: 9, minuto: 0),
      (hora: 9, minuto: 30),
    ]);
    expect(slots.map((s) => s.disponivel), [true, false]);
  });

  test('diasComRegistro manda ano e mês e converte as datas', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, ['2026-10-03', '2026-10-25']),
    );
    final datasource = AgendaRemoteDataSourceImpl(dioDeTeste(adapter));

    final dias = await datasource.diasComRegistro(
      const MesParams(ano: 2026, mes: 10),
    );

    expect(adapter.requisicoes.single.uri.queryParameters, {
      'ano': '2026',
      'mes': '10',
    });
    expect(dias, [DateTime(2026, 10, 3), DateTime(2026, 10, 25)]);
  });

  test('pendencias lê origem, cliente e valor', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, [
        {
          'origem': 'agenda',
          'id': 4,
          'data': '2026-10-20',
          'cliente_id': 7,
          'cliente_nome': 'Ana',
          'servico_nome': 'Corte',
          'valor': '45.50',
          'servicos': <Object>[],
        },
        {
          'origem': 'kanban',
          'id': 9,
          'data': '2026-10-21',
          'cliente_id': 8,
          'cliente_nome': 'Bia',
          'servico_nome': 'Banho',
          'valor': '60.00',
          'servicos': <Object>[],
        },
      ]),
    );
    final datasource = AgendaRemoteDataSourceImpl(dioDeTeste(adapter));

    final pendencias = await datasource.pendencias();

    expect(adapter.requisicoes.single.path, 'agenda/pendencias/');
    expect(pendencias.first.origemAgenda, isTrue);
    expect(pendencias.first.valor, Decimal.parse('45.50'));
    expect(pendencias.last.origemAgenda, isFalse);
    expect(pendencias.last.data, DateTime(2026, 10, 21));
  });

  group('bloqueios', () {
    final almoco = {
      'id': 5,
      'colaborador': 2,
      'colaborador_nome': 'Bia',
      'data_inicio': '2026-10-25',
      'data_fim': null,
      'hora_inicio': '12:00:00',
      'hora_fim': '13:00:00',
      'motivo': 'Almoço',
      'criado_em': '2026-10-20T10:00:00-03:00',
    };

    test('listarBloqueiosDoDia manda o dia e o profissional', () async {
      final adapter = FakeAdapter(
        (_) async => respostaJson(200, _pagina([almoco])),
      );
      final datasource = AgendaRemoteDataSourceImpl(dioDeTeste(adapter));

      final lista = await datasource.listarBloqueiosDoDia(
        DateTime(2026, 11, 3),
        colaboradorId: 2,
      );

      final requisicao = adapter.requisicoes.single;
      expect(requisicao.path, 'agenda/bloqueios/');
      expect(requisicao.queryParameters['data'], '2026-11-03');
      expect(requisicao.queryParameters['colaborador'], 2);
      final b = lista.single.toEntity();
      expect(b.fixo, isTrue);
      expect(b.diaInteiro, isFalse);
      expect(b.horaInicio, (hora: 12, minuto: 0));
      expect(b.motivo, 'Almoço');
    });

    test(
      'criarBloqueio manda o corpo do contrato; dia inteiro vai nulo',
      () async {
        final adapter = FakeAdapter((_) async => respostaJson(201, almoco));
        final datasource = AgendaRemoteDataSourceImpl(dioDeTeste(adapter));

        await datasource.criarBloqueio(
          NovoBloqueioParams(
            colaboradorId: 2,
            dataInicio: DateTime(2026, 11, 3),
            dataFim: DateTime(2026, 11, 9),
            motivo: 'Férias',
          ),
        );

        final requisicao = adapter.requisicoes.single;
        expect(requisicao.method, 'POST');
        expect(requisicao.data, {
          'colaborador': 2,
          'data_inicio': '2026-11-03',
          'data_fim': '2026-11-09',
          'hora_inicio': null,
          'hora_fim': null,
          'motivo': 'Férias',
        });
      },
    );

    test('o bloqueio do negócio vem e vai com o colaborador nulo', () async {
      final fechado = {
        ...almoco,
        'id': 8,
        'colaborador': null,
        'colaborador_nome': null,
      };
      final adapter = FakeAdapter((_) async => respostaJson(201, fechado));
      final datasource = AgendaRemoteDataSourceImpl(dioDeTeste(adapter));

      final criado = await datasource.criarBloqueio(
        NovoBloqueioParams(
          dataInicio: DateTime(2026, 11, 3),
          dataFim: DateTime(2026, 11, 3),
          horaInicio: (hora: 12, minuto: 0),
          horaFim: (hora: 13, minuto: 0),
          motivo: 'Almoço',
        ),
      );

      final corpo = adapter.requisicoes.single.data as Map<String, dynamic>;
      // null explícito: é assim que a API sabe que é do negócio inteiro
      expect(corpo.containsKey('colaborador'), isTrue);
      expect(corpo['colaborador'], isNull);
      final b = criado.toEntity();
      expect(b.doNegocio, isTrue);
      expect(b.colaboradorId, isNull);
      expect(b.colaboradorNome, '');
    });

    test('excluirBloqueio faz DELETE no id', () async {
      final adapter = FakeAdapter((_) async => respostaJson(204, null));
      final datasource = AgendaRemoteDataSourceImpl(dioDeTeste(adapter));

      await datasource.excluirBloqueio(5);

      final requisicao = adapter.requisicoes.single;
      expect(requisicao.method, 'DELETE');
      expect(requisicao.path, 'agenda/bloqueios/5/');
    });
  });
}
