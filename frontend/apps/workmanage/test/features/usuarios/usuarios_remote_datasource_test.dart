import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/usuarios/data/datasources/usuarios_remote_datasource.dart';
import 'package:managers/features/usuarios/data/models/colaborador_model.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> _colaboradorJson(
  int id, {
  String? papel = 'colaborador',
}) => {
  'id': id,
  'nome': 'Ana Silva',
  'email': 'ana$id@demo.com',
  'tem_acesso': true,
  'funcao': 'Cabeleireira',
  'tipo': 'parceiro',
  'comissao_percentual': '40.00',
  'pode_cobrar': true,
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
    expect(perfil.tipo, VinculoColaborador.parceiro);
    expect(perfil.comissaoPercentual, Decimal.parse('40.00'));
    expect(perfil.veValores, isTrue);
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
    expect(lista.map((c) => c.toEntity().id), [1, 2]);
  });

  test('quem não tem login vem sem e-mail nem papel; o colaborador comum '
      'não vê valores e só cobra com a flag', () {
    final json = _colaboradorJson(7, papel: null)
      ..['email'] = ''
      ..['tem_acesso'] = false
      ..['tipo'] = 'colaborador'
      ..['comissao_percentual'] = null
      ..['pode_cobrar'] = false;

    final colaborador = ColaboradorModel.fromJson(json).toEntity();

    expect(colaborador.nome, 'Ana Silva');
    expect(colaborador.temAcesso, isFalse);
    expect(colaborador.papel, isNull);
    expect(colaborador.ehProprietario, isFalse);
    expect(colaborador.tipo, VinculoColaborador.colaborador);
    expect(colaborador.comissaoPercentual, isNull);
    expect(colaborador.veValores, isFalse);
    expect(colaborador.cobra, isFalse);
  });
}
