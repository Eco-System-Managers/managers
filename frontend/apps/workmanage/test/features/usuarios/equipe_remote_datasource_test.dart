import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/usuarios/data/datasources/usuarios_remote_datasource.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/params/equipe_params.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/fake_sessao_repository.dart';

Map<String, dynamic> _colaboradorJson(
  int id, {
  bool ativo = true,
  String? papel = 'colaborador',
}) => {
  'id': id,
  'nome': 'Bia Souza',
  'email': 'bia@demo.com',
  'tem_acesso': true,
  'funcao': 'Barbeira',
  'tipo': 'parceiro',
  'comissao_percentual': null,
  'pode_cobrar': true,
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
  test('obter e atualizar falam com colaboradores/{id}/; o corpo leva o '
      'vínculo e a comissão como string', () async {
    final adapter = FakeAdapter(
      (_) async =>
          respostaJson(200, _colaboradorJson(2, papel: 'proprietario')),
    );
    final datasource = UsuariosRemoteDataSourceImpl(dioDeTeste(adapter));

    final obtido = (await datasource.obter(2)).toEntity();
    await datasource.atualizar(
      2,
      DadosColaborador(
        nome: 'Bia Souza',
        funcao: 'Barbeira',
        comissaoPercentual: Decimal.parse('40'),
      ),
    );

    expect(obtido.nome, 'Bia Souza');
    expect(obtido.papel, Papel.proprietario);
    expect(adapter.requisicoes[0].method, 'GET');
    expect(adapter.requisicoes[0].path, 'colaboradores/2/');
    expect(adapter.requisicoes[1].method, 'PATCH');
    expect(adapter.requisicoes[1].path, 'colaboradores/2/');
    expect(adapter.requisicoes[1].data, {
      'nome': 'Bia Souza',
      'funcao': 'Barbeira',
      'tipo': 'parceiro',
      'comissao_percentual': '40.00',
      'pode_cobrar': true,
    });
  });

  test(
    'criar cadastra sem login e convidar liga o convite ao registro',
    () async {
      final adapter = FakeAdapter((options) async {
        if (options.path.endsWith('convidar/')) {
          return respostaJson(201, {..._conviteJson(5), 'colaborador': 9});
        }
        return respostaJson(201, {
          ..._colaboradorJson(9, papel: null),
          'nome': 'João',
          'email': '',
          'tem_acesso': false,
          'tipo': 'colaborador',
        });
      });
      final datasource = UsuariosRemoteDataSourceImpl(dioDeTeste(adapter));

      final criado = (await datasource.criar(
        const DadosColaborador(
          nome: 'João',
          funcao: 'Lavador',
          tipo: VinculoColaborador.colaborador,
          podeCobrar: false,
        ),
      )).toEntity();
      final convite = (await datasource.convidar(
        9,
        'joao@demo.com',
      )).toEntity();

      expect(criado.temAcesso, isFalse);
      expect(criado.tipo, VinculoColaborador.colaborador);
      expect(adapter.requisicoes[0].method, 'POST');
      expect(adapter.requisicoes[0].path, 'colaboradores/');
      expect(adapter.requisicoes[0].data, {
        'nome': 'João',
        'funcao': 'Lavador',
        'tipo': 'colaborador',
        'comissao_percentual': null,
        'pode_cobrar': false,
      });
      expect(adapter.requisicoes[1].path, 'colaboradores/9/convidar/');
      expect(adapter.requisicoes[1].data, {'email': 'joao@demo.com'});
      expect(convite.email, 'caio@demo.com');
    },
  );

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

  test('o convite traz a quem pertence e o link; cancelarConvite faz '
      'DELETE', () async {
    final adapter = FakeAdapter((options) async {
      if (options.method == 'DELETE') return respostaJson(204, null);
      return respostaJson(200, {
        'count': 1,
        'next': null,
        'results': [
          {
            ..._conviteJson(5),
            'colaborador': 9,
            'link': 'http://localhost:5173/convite/abc-123',
          },
        ],
      });
    });
    final datasource = UsuariosRemoteDataSourceImpl(dioDeTeste(adapter));

    final convite = (await datasource.listarConvites()).single.toEntity();
    await datasource.cancelarConvite(5);

    expect(convite.colaboradorId, 9);
    expect(convite.link, 'http://localhost:5173/convite/abc-123');
    expect(adapter.requisicoes[1].method, 'DELETE');
    expect(adapter.requisicoes[1].path, 'convites/5/');
  });

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
