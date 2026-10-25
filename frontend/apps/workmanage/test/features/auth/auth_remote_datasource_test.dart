import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/auth/data/datasources/auth_remote_datasource.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/fake_sessao_repository.dart';

void main() {
  late FakeAdapter adapter;
  late AuthRemoteDataSourceImpl datasource;

  setUp(() {
    adapter = FakeAdapter((_) async => respostaJson(200, {'detail': 'ok'}));
    datasource = AuthRemoteDataSourceImpl(dioDeTeste(adapter));
  });

  test('login manda e-mail e senha e devolve a sessão', () async {
    adapter = FakeAdapter(
      (_) async => respostaJson(200, sessaoJson(sessaoDeTeste)),
    );
    datasource = AuthRemoteDataSourceImpl(dioDeTeste(adapter));

    final sessao = await datasource.login(
      email: 'dono@demo.com',
      senha: 'SenhaForte123!',
    );

    final requisicao = adapter.requisicoes.single;
    expect(requisicao.method, 'POST');
    expect(requisicao.path, 'auth/login/');
    expect(requisicao.data, {
      'email': 'dono@demo.com',
      'senha': 'SenhaForte123!',
    });
    expect(requisicao.headers['X-Client-Platform'], 'mobile');
    expect(sessao.toEntity(), sessaoDeTeste);
  });

  test('login recusado sobe como DioException com o corpo da API', () async {
    adapter = FakeAdapter(
      (_) async => respostaErro(
        401,
        'credenciais_invalidas',
        detail: 'E-mail ou senha inválidos.',
      ),
    );
    datasource = AuthRemoteDataSourceImpl(dioDeTeste(adapter));

    await expectLater(
      datasource.login(email: 'a@b.c', senha: 'x'),
      throwsA(
        isA<DioException>().having(
          (e) => (e.response?.data as Map)['code'],
          'code',
          'credenciais_invalidas',
        ),
      ),
    );
  });

  test('as três etapas da recuperação batem com o contrato', () async {
    await datasource.sendRecoveryCode('dono@demo.com');
    await datasource.verifyRecoveryCode(
      email: 'dono@demo.com',
      codigo: '12345678',
    );
    await datasource.resetPassword(
      email: 'dono@demo.com',
      codigo: '12345678',
      novaSenha: 'NovaSenha123!',
    );

    expect(adapter.requisicoes.map((r) => r.path), [
      'auth/recuperar-senha/',
      'auth/verificar-codigo/',
      'auth/nova-senha/',
    ]);
    expect(adapter.requisicoes[0].data, {'email': 'dono@demo.com'});
    expect(adapter.requisicoes[1].data, {
      'email': 'dono@demo.com',
      'codigo': '12345678',
    });
    expect(adapter.requisicoes[2].data, {
      'email': 'dono@demo.com',
      'codigo': '12345678',
      'nova_senha': 'NovaSenha123!',
    });
  });

  test('logout manda o refresh no corpo', () async {
    await datasource.logout('refresh-1');

    final requisicao = adapter.requisicoes.single;
    expect(requisicao.path, 'auth/logout/');
    expect(requisicao.data, {'refresh': 'refresh-1'});
  });
}
