import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/register/data/datasources/register_remote_datasource.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/fake_sessao_repository.dart';

void main() {
  test('solicitar manda os quatro campos do cadastro', () async {
    final adapter = FakeAdapter((_) async => respostaJson(202, {}));
    final datasource = RegisterRemoteDataSourceImpl(dioDeTeste(adapter));

    await datasource.register(
      nomeEmpresa: 'Barbearia Central',
      nome: 'Wilson',
      email: 'dono@demo.com',
      senha: 'SenhaForte123!',
    );

    final requisicao = adapter.requisicoes.single;
    expect(requisicao.path, 'auth/cadastro/solicitar/');
    expect(requisicao.data, {
      'nome_empresa': 'Barbearia Central',
      'nome': 'Wilson',
      'email': 'dono@demo.com',
      'senha': 'SenhaForte123!',
    });
  });

  test('confirmar devolve a sessão que a API cria com a empresa', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(201, sessaoJson(sessaoDeTeste)),
    );
    final datasource = RegisterRemoteDataSourceImpl(dioDeTeste(adapter));

    final sessao = await datasource.confirm(
      email: 'dono@demo.com',
      code: '12345678',
    );

    final requisicao = adapter.requisicoes.single;
    expect(requisicao.path, 'auth/cadastro/confirmar/');
    expect(requisicao.data, {'email': 'dono@demo.com', 'codigo': '12345678'});
    expect(sessao.toEntity(), sessaoDeTeste);
  });

  test('reenviar manda só o e-mail', () async {
    final adapter = FakeAdapter((_) async => respostaJson(200, {}));
    final datasource = RegisterRemoteDataSourceImpl(dioDeTeste(adapter));

    await datasource.resendCode('dono@demo.com');

    expect(adapter.requisicoes.single.path, 'auth/cadastro/reenviar/');
    expect(adapter.requisicoes.single.data, {'email': 'dono@demo.com'});
  });
}
