import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/clientes/data/datasources/clientes_remote_datasource.dart';
import 'package:managers/features/clientes/data/models/cliente_model.dart';
import 'package:managers/features/clientes/domain/entities/cliente.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> _clienteJson(int id, {String origem = 'manual'}) => {
  'id': id,
  'nome': 'Ana Silva',
  'telefone': '19999990000',
  'email': 'ana@demo.com',
  'cpf': '52998224725',
  'data_nascimento': '1990-05-20',
  'cep': '13604512',
  'endereco': 'Rua Um',
  'numero_endereco': '10',
  'observacao': 'Prefere manhã',
  'alergia': '',
  'convenio': '',
  'carteirinha': '',
  'plano_saude': '',
  'validade_plano_saude': null,
  'criado_em': '2026-10-20T10:00:00-03:00',
  'origem': origem,
  'veiculos': <Object>[],
  'pets': <Object>[],
  'foto': origem == 'servicemanage' ? 'https://s3/foto.webp?assinada' : '',
};

void main() {
  test('listar manda a página e a busca e lê a paginação', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, {
        'count': 41,
        'next': 'http://api.teste/api/v1/clientes/?page=3&search=ana',
        'previous': 'http://api.teste/api/v1/clientes/?page=1&search=ana',
        'results': [_clienteJson(1), _clienteJson(2)],
      }),
    );
    final datasource = ClientesRemoteDataSourceImpl(dioDeTeste(adapter));

    final pagina = await datasource.listar(pagina: 2, busca: 'ana');

    final uri = adapter.requisicoes.single.uri;
    expect(uri.path, endsWith('clientes/'));
    expect(uri.queryParameters['page'], '2');
    expect(uri.queryParameters['search'], 'ana');
    expect(pagina.count, 41);
    expect(pagina.next, isNotNull);
    expect(pagina.results.map((c) => c.id), [1, 2]);
  });

  test('o model converte datas, origem e foto', () {
    final cliente = ClienteModel.fromJson(
      _clienteJson(1, origem: 'servicemanage'),
    ).toEntity();

    expect(cliente.dataNascimento, DateTime(1990, 5, 20));
    expect(cliente.criadoEm?.toUtc(), DateTime.utc(2026, 10, 20, 13));
    expect(cliente.origem, OrigemCliente.servicemanage);
    expect(cliente.veioDoApp, isTrue);
    expect(cliente.fotoUrl, startsWith('https://'));
  });

  test(
    'criar manda o JSON do contrato, com a data no formato da API',
    () async {
      final adapter = FakeAdapter(
        (_) async => respostaJson(201, _clienteJson(9)),
      );
      final datasource = ClientesRemoteDataSourceImpl(dioDeTeste(adapter));
      final nova = Cliente(
        nome: 'Ana Silva',
        telefone: '19999990000',
        cpf: '52998224725',
        dataNascimento: DateTime(1990, 5, 20),
        cep: '13604512',
        endereco: 'Rua Um',
        numeroEndereco: '10',
        observacao: 'Prefere manhã',
      );

      final criado = await datasource.criar(ClienteModel.fromEntity(nova));

      final requisicao = adapter.requisicoes.single;
      expect(requisicao.method, 'POST');
      expect(requisicao.path, 'clientes/');
      expect(requisicao.data, {
        'nome': 'Ana Silva',
        'telefone': '19999990000',
        'email': '',
        'cpf': '52998224725',
        'data_nascimento': '1990-05-20',
        'cep': '13604512',
        'endereco': 'Rua Um',
        'numero_endereco': '10',
        'observacao': 'Prefere manhã',
        'alergia': '',
      });
      expect(criado.id, 9);
    },
  );

  test('sem nascimento, a data vai nula', () {
    final json = ClienteModel.fromEntity(
      const Cliente(nome: 'Ana', telefone: '19999990000'),
    ).toJson();
    expect(json['data_nascimento'], isNull);
  });

  test('atualizar faz PATCH no id e remover faz DELETE', () async {
    final adapter = FakeAdapter((options) async {
      if (options.method == 'DELETE') return respostaJson(204, null);
      return respostaJson(200, _clienteJson(3));
    });
    final datasource = ClientesRemoteDataSourceImpl(dioDeTeste(adapter));

    await datasource.atualizar(3, ClienteModel.fromJson(_clienteJson(3)));
    await datasource.remover(3);

    expect(adapter.requisicoes[0].method, 'PATCH');
    expect(adapter.requisicoes[0].path, 'clientes/3/');
    expect(adapter.requisicoes[1].method, 'DELETE');
    expect(adapter.requisicoes[1].path, 'clientes/3/');
  });
}
