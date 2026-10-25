import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/usuarios/data/datasources/usuarios_remote_datasource.dart';
import 'package:managers/features/usuarios/data/models/colaborador_model.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> _colaboradorJson(int id, {String papel = 'colaborador'}) =>
    {
      'id': id,
      'user': {
        'id': id,
        'first_name': 'Ana',
        'last_name': 'Silva',
        'email': 'ana$id@demo.com',
      },
      'funcao': 'Cabeleireira',
      'papel': papel,
      'ativo': true,
      'criado_em': '2026-10-24T10:00:00-03:00',
    };

void main() {
  test('meuPerfil lê /colaboradores/me/ e traz o papel', () async {
    final adapter = FakeAdapter(
      (_) async =>
          respostaJson(200, _colaboradorJson(1, papel: 'proprietario')),
    );
    final datasource = UsuariosRemoteDataSourceImpl(dioDeTeste(adapter));

    final perfil = (await datasource.meuPerfil()).toEntity();

    expect(adapter.requisicoes.single.path, 'colaboradores/me/');
    expect(perfil.nome, 'Ana Silva');
    expect(perfil.email, 'ana1@demo.com');
    expect(perfil.funcao, 'Cabeleireira');
    expect(perfil.papel, Papel.proprietario);
    expect(perfil.ehProprietario, isTrue);
  });

  test('sem colaborador (404) a exceção sobe com o code da API', () async {
    final adapter = FakeAdapter(
      (_) async => respostaErro(
        404,
        'sem_colaborador',
        detail: 'Usuário sem perfil de colaborador.',
      ),
    );
    final datasource = UsuariosRemoteDataSourceImpl(dioDeTeste(adapter));

    await expectLater(
      datasource.meuPerfil(),
      throwsA(
        isA<DioException>().having(
          (e) => (e.response?.data as Map)['code'],
          'code',
          'sem_colaborador',
        ),
      ),
    );
  });

  test('listar segue a paginação e manda a busca', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, {
        'count': 2,
        'next': null,
        'previous': null,
        'results': [_colaboradorJson(1), _colaboradorJson(2)],
      }),
    );
    final datasource = UsuariosRemoteDataSourceImpl(dioDeTeste(adapter));

    final lista = await datasource.listar(busca: 'ana');

    final uri = adapter.requisicoes.single.uri;
    expect(uri.path, endsWith('colaboradores/'));
    expect(uri.queryParameters['search'], 'ana');
    expect(uri.queryParameters['page_size'], '100');
    expect(lista.map((c) => c.id), [1, 2]);
  });

  test('sem nome cadastrado, o e-mail identifica a pessoa', () {
    final json = _colaboradorJson(7)
      ..['user'] = {'first_name': '', 'last_name': '', 'email': 'x@y.com'}
      ..['papel'] = null;

    final colaborador = ColaboradorModel.fromJson(json).toEntity();

    expect(colaborador.nome, 'x@y.com');
    expect(colaborador.papel, isNull);
    expect(colaborador.ehProprietario, isFalse);
  });
}
