import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/servicos/data/datasources/servicos_remote_datasource.dart';
import 'package:managers/features/servicos/data/models/servico_model.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> _servicoJson(int id, {bool ativo = true}) => {
  'id': id,
  'nome': 'Corte',
  'descricao': '',
  'duracao': 30,
  'preco': '45.50',
  'taxa_cancelamento_tipo': 'percentual',
  'taxa_cancelamento_valor': '10.00',
  'ativo': ativo,
  'colaboradores': [1, 2],
};

void main() {
  test('listar manda busca e filtro de ativo e lê a paginação', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, {
        'count': 1,
        'next': null,
        'previous': null,
        'results': [_servicoJson(1)],
      }),
    );
    final datasource = ServicosRemoteDataSourceImpl(dioDeTeste(adapter));

    final lista = await datasource.listar(busca: 'cor', ativo: true);

    final uri = adapter.requisicoes.single.uri;
    expect(uri.path, endsWith('servicos/'));
    expect(uri.queryParameters['search'], 'cor');
    expect(uri.queryParameters['ativo'], 'true');
    expect(uri.queryParameters['page_size'], '100');

    final servico = lista.single.toEntity();
    expect(servico.preco, Decimal.parse('45.5'));
    expect(servico.taxaCancelamentoTipo, TipoTaxaCancelamento.percentual);
    expect(servico.taxaCancelamentoValor, Decimal.fromInt(10));
    expect(servico.colaboradores, [1, 2]);
  });

  test('sem filtros, não manda search nem ativo', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, {
        'count': 0,
        'next': null,
        'previous': null,
        'results': <Object>[],
      }),
    );
    final datasource = ServicosRemoteDataSourceImpl(dioDeTeste(adapter));

    await datasource.listar();

    final query = adapter.requisicoes.single.uri.queryParameters;
    expect(query.containsKey('search'), isFalse);
    expect(query.containsKey('ativo'), isFalse);
  });

  test('criar manda o JSON do contrato, com preço como string', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(201, _servicoJson(9)),
    );
    final datasource = ServicosRemoteDataSourceImpl(dioDeTeste(adapter));
    final novo = Servico(
      nome: 'Corte',
      duracao: 30,
      preco: Decimal.parse('45.5'),
      taxaCancelamentoTipo: TipoTaxaCancelamento.percentual,
      taxaCancelamentoValor: Decimal.fromInt(10),
      colaboradores: const [1, 2],
    );

    final criado = await datasource.criar(ServicoModel.fromEntity(novo));

    final requisicao = adapter.requisicoes.single;
    expect(requisicao.method, 'POST');
    expect(requisicao.path, 'servicos/');
    expect(requisicao.data, {
      'nome': 'Corte',
      'descricao': '',
      'duracao': 30,
      'preco': '45.50',
      'taxa_cancelamento_tipo': 'percentual',
      'taxa_cancelamento_valor': '10.00',
      'ativo': true,
      'colaboradores': [1, 2],
    });
    expect(criado.id, 9);
  });

  test('sem taxa, o tipo vai vazio e o valor zerado', () {
    final model = ServicoModel.fromEntity(
      Servico(nome: 'Barba', duracao: 20, preco: Decimal.fromInt(30)),
    );
    expect(model.toJson()['taxa_cancelamento_tipo'], '');
    expect(model.toJson()['taxa_cancelamento_valor'], '0.00');
  });

  test('atualizar faz PATCH no id e alterarAtivo manda só o ativo', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, _servicoJson(3, ativo: false)),
    );
    final datasource = ServicosRemoteDataSourceImpl(dioDeTeste(adapter));

    await datasource.atualizar(3, ServicoModel.fromJson(_servicoJson(3)));
    final alterado = await datasource.alterarAtivo(3, false);

    expect(adapter.requisicoes[0].method, 'PATCH');
    expect(adapter.requisicoes[0].path, 'servicos/3/');
    expect(adapter.requisicoes[1].path, 'servicos/3/');
    expect(adapter.requisicoes[1].data, {'ativo': false});
    expect(alterado.ativo, isFalse);
  });
}
