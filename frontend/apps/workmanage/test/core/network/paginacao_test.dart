import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/network/paginacao.dart';

import '../../helpers/fake_adapter.dart';

void main() {
  test('Pagina.fromJson lê o formato da API', () {
    final pagina = Pagina.fromJson({
      'count': 2,
      'next': null,
      'previous': 'http://api/x/?page=1',
      'results': [
        {'id': 1},
        {'id': 2},
      ],
    }, (json) => json['id'] as int);

    expect(pagina.count, 2);
    expect(pagina.next, isNull);
    expect(pagina.previous, 'http://api/x/?page=1');
    expect(pagina.results, [1, 2]);
  });

  test('buscarTudo pede page_size=100 e segue o next até o fim', () async {
    final adapter = FakeAdapter((options) async {
      if (options.uri.queryParameters['page'] == '2') {
        return respostaJson(200, {
          'count': 3,
          'next': null,
          'previous': 'http://api.teste/api/v1/agendamentos/?page=1',
          'results': [
            {'id': 3},
          ],
        });
      }
      return respostaJson(200, {
        'count': 3,
        'next': 'http://api.teste/api/v1/agendamentos/?data=2026-10-19&page=2',
        'previous': null,
        'results': [
          {'id': 1},
          {'id': 2},
        ],
      });
    });
    final dio = dioDeTeste(adapter);

    final todos = await buscarTudo(
      dio,
      'agendamentos/',
      query: {'data': '2026-10-19'},
      item: (json) => json['id'] as int,
    );

    expect(todos, [1, 2, 3]);
    expect(adapter.requisicoes.length, 2);
    final primeira = adapter.requisicoes.first.uri.queryParameters;
    expect(primeira['page_size'], '100');
    expect(primeira['data'], '2026-10-19');
    expect(adapter.requisicoes.last.uri.queryParameters['page'], '2');
  });

  test('buscarTudo com uma página só faz uma requisição', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, {
        'count': 0,
        'next': null,
        'previous': null,
        'results': <Object>[],
      }),
    );

    final todos = await buscarTudo(
      dioDeTeste(adapter),
      'clientes/',
      item: (json) => json,
    );

    expect(todos, isEmpty);
    expect(adapter.requisicoes.length, 1);
    expect(adapter.requisicoes.single.method, 'GET');
  });
}
