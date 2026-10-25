import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/cep/via_cep_datasource.dart';

import '../../helpers/fake_adapter.dart';

void main() {
  test('devolve o endereço do CEP, com o CEP só em dígitos', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, {
        'cep': '13604-512',
        'logradouro': 'Avenida Fábio da Silva Prado',
        'bairro': 'Jardim Alvorada',
        'localidade': 'Araras',
        'uf': 'SP',
      }),
    );
    final datasource = ViaCepDataSource(dioDeTeste(adapter));

    final endereco = await datasource.buscar('13604-512');

    expect(adapter.requisicoes.single.path, '13604512/json/');
    expect(endereco.cep, '13604512');
    expect(endereco.logradouro, 'Avenida Fábio da Silva Prado');
    expect(endereco.bairro, 'Jardim Alvorada');
    expect(endereco.cidade, 'Araras');
    expect(endereco.uf, 'SP');
  });

  test('CEP inexistente (200 com erro) vira CepNaoEncontradoException', () {
    final adapter = FakeAdapter((_) async => respostaJson(200, {'erro': true}));
    final datasource = ViaCepDataSource(dioDeTeste(adapter));

    expect(
      datasource.buscar('00000000'),
      throwsA(isA<CepNaoEncontradoException>()),
    );
  });

  test('CEP com menos de 8 dígitos nem vai à rede', () async {
    final adapter = FakeAdapter((_) async => respostaJson(200, {}));
    final datasource = ViaCepDataSource(dioDeTeste(adapter));

    await expectLater(
      datasource.buscar('1360'),
      throwsA(isA<CepNaoEncontradoException>()),
    );
    expect(adapter.requisicoes, isEmpty);
  });
}
