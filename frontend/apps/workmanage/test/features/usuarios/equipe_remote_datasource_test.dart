import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/usuarios/data/datasources/usuarios_remote_datasource.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/fake_sessao_repository.dart';

Map<String, dynamic> _colaboradorJson(
  int id, {
  bool ativo = true,
  String papel = 'colaborador',
}) => {
  'id': id,
  'user': {'first_name': 'Bia', 'last_name': 'Souza', 'email': 'bia@demo.com'},
  'funcao': 'Barbeira',
  'papel': papel,
  'ativo': ativo,
  'criado_em': '2026-10-20T10:00:00-03:00',
};

Map<String, dynamic> _conviteJson(int id) => {
  'id': id,
  'nome': 'Caio',
  'email': 'caio@demo.com',
  'aceito': false,
  'criado_em': '2026-10-25T10:00:00-03:00',
  'expira_em': '2026-10-27T10:00:00-03:00',
};

void main() {
  test('obter e atualizarFuncao falam com colaboradores/{id}/', () async {
    final adapter = FakeAdapter(
      (_) async =>
          respostaJson(200, _colaboradorJson(2, papel: 'proprietario')),
    );
    final datasource = UsuariosRemoteDataSourceImpl(dioDeTeste(adapter));

    final obtido = (await datasource.obter(2)).toEntity();
    await datasource.atualizarFuncao(2, 'Barbeira');

    expect(obtido.nome, 'Bia Souza');
    expect(obtido.papel, Papel.proprietario);
    expect(adapter.requisicoes[0].method, 'GET');
    expect(adapter.requisicoes[0].path, 'colaboradores/2/');
    expect(adapter.requisicoes[1].method, 'PATCH');
    expect(adapter.requisicoes[1].path, 'colaboradores/2/');
    expect(adapter.requisicoes[1].data, {'funcao': 'Barbeira'});
  });

  test('ativar, desativar e remover usam as ações do contrato', () async {
    final adapter = FakeAdapter((options) async {
      if (options.path.endsWith('ativar/')) {
        return respostaJson(200, _colaboradorJson(2));
      }
      return respostaJson(204, null);
    });
    final datasource = UsuariosRemoteDataSourceImpl(dioDeTeste(adapter));

    await datasource.ativar(2);
    await datasource.desativar(2);
    await datasource.remover(2);

    expect(adapter.requisicoes.map((r) => '${r.method} ${r.path}'), [
      'POST colaboradores/2/ativar/',
      'POST colaboradores/2/desativar/',
      'DELETE colaboradores/2/remover/',
    ]);
  });

  test('agendamentosPendentes lê o total', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, {'tem_pendentes': true, 'total': 3}),
    );
    final datasource = UsuariosRemoteDataSourceImpl(dioDeTeste(adapter));

    final total = await datasource.agendamentosPendentes(2);

    expect(total, 3);
    expect(
      adapter.requisicoes.single.path,
      'colaboradores/2/agendamentos-pendentes/',
    );
  });

  test('listarConvites segue a paginação e converte as datas', () async {
    final adapter = FakeAdapter((options) async {
      if (options.uri.queryParameters['page'] == '2') {
        return respostaJson(200, {
          'count': 2,
          'next': null,
          'previous': 'x',
          'results': [_conviteJson(6)],
        });
      }
      return respostaJson(200, {
        'count': 2,
        'next': 'http://api.teste/api/v1/convites/?page=2&page_size=100',
        'previous': null,
        'results': [_conviteJson(5)],
      });
    });
    final datasource = UsuariosRemoteDataSourceImpl(dioDeTeste(adapter));

    final convites = await datasource.listarConvites();

    expect(convites.map((c) => c.toEntity().id), [5, 6]);
    expect(adapter.requisicoes.first.uri.queryParameters['page_size'], '100');
    expect(
      convites.first.toEntity().expiraEm.toUtc(),
      DateTime.utc(2026, 10, 27, 13),
    );
  });

  test(
    'criarConvite manda nome e e-mail; cancelarConvite faz DELETE',
    () async {
      final adapter = FakeAdapter((options) async {
        if (options.method == 'DELETE') return respostaJson(204, null);
        return respostaJson(201, _conviteJson(5));
      });
      final datasource = UsuariosRemoteDataSourceImpl(dioDeTeste(adapter));

      final criado = await datasource.criarConvite(
        nome: 'Caio',
        email: 'caio@demo.com',
      );
      await datasource.cancelarConvite(5);

      expect(criado.toEntity().email, 'caio@demo.com');
      expect(adapter.requisicoes[0].method, 'POST');
      expect(adapter.requisicoes[0].path, 'convites/');
      expect(adapter.requisicoes[0].data, {
        'nome': 'Caio',
        'email': 'caio@demo.com',
      });
      expect(adapter.requisicoes[1].method, 'DELETE');
      expect(adapter.requisicoes[1].path, 'convites/5/');
    },
  );

  test('infoConvite e aceitarConvite usam o token na rota; aceitar devolve '
      'a sessão', () async {
    final adapter = FakeAdapter((options) async {
      if (options.method == 'POST') {
        return respostaJson(201, sessaoJson(sessaoDeTeste));
      }
      return respostaJson(200, {
        'nome': 'Caio',
        'email': 'caio@demo.com',
        'expira_em': '2026-10-27T10:00:00-03:00',
      });
    });
    final datasource = UsuariosRemoteDataSourceImpl(dioDeTeste(adapter));

    final info = (await datasource.infoConvite('abc-123')).toEntity();
    final sessao = (await datasource.aceitarConvite(
      token: 'abc-123',
      senha: 'SenhaForte123!',
    )).toEntity();

    expect(info.email, 'caio@demo.com');
    expect(adapter.requisicoes[0].path, 'convites/info/abc-123/');
    expect(adapter.requisicoes[1].path, 'convites/aceitar/abc-123/');
    expect(adapter.requisicoes[1].data, {'senha': 'SenhaForte123!'});
    expect(sessao, sessaoDeTeste);
  });
}
