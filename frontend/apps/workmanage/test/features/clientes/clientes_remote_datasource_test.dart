import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/clientes/data/datasources/clientes_remote_datasource.dart';
import 'package:managers/features/clientes/data/models/cliente_model.dart';
import 'package:managers/features/clientes/domain/entities/cliente.dart';
import 'package:managers/features/clientes/domain/entities/objeto_cliente.dart';

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

  test('o model lê os veículos e pets aninhados', () {
    final json = _clienteJson(1)
      ..['veiculos'] = [
        {
          'id': 10,
          'cliente': 1,
          'placa': 'ABC1D23',
          'marca': 'Fiat',
          'modelo': 'Uno',
          'cor': 'Prata',
          'criado_em': '2026-10-20T10:00:00-03:00',
        },
      ]
      ..['pets'] = [
        {
          'id': 11,
          'cliente': 1,
          'nome': 'Rex',
          'especie': 'Cachorro',
          'raca': 'Poodle',
          'porte': 'pequeno',
          'data_nascimento': '2020-01-05',
          'criado_em': '2026-10-20T10:00:00-03:00',
        },
      ];

    final cliente = ClienteModel.fromJson(json).toEntity();

    expect(cliente.veiculos.single.titulo, 'Fiat Uno');
    expect(cliente.pets.single.porte, PortePet.pequeno);
    expect(cliente.pets.single.dataNascimento, DateTime(2020, 1, 5));
    expect(cliente.objetosDoTipo(TipoObjeto.pet).single.titulo, 'Rex');
    expect(
      cliente.objetosDoTipo(TipoObjeto.veiculo).single.detalhe,
      'ABC1D23 · Prata',
    );
  });

  test('veículo e pet usam as rotas próprias', () async {
    final adapter = FakeAdapter((options) async {
      if (options.method == 'DELETE') return respostaJson(204, null);
      if (options.path.startsWith('pets')) {
        return respostaJson(200, {
          'id': 11,
          'cliente': 1,
          'nome': 'Rex',
          'especie': '',
          'raca': '',
          'porte': '',
          'data_nascimento': null,
          'criado_em': '2026-10-20T10:00:00-03:00',
        });
      }
      return respostaJson(201, {
        'id': 10,
        'cliente': 1,
        'placa': 'ABC1D23',
        'marca': 'Fiat',
        'modelo': 'Uno',
        'cor': 'Prata',
        'criado_em': '2026-10-20T10:00:00-03:00',
      });
    });
    final datasource = ClientesRemoteDataSourceImpl(dioDeTeste(adapter));

    final veiculo = await datasource.criarVeiculo(
      const Veiculo(
        clienteId: 1,
        placa: 'ABC1D23',
        marca: 'Fiat',
        modelo: 'Uno',
        cor: 'Prata',
      ),
    );
    final pet = await datasource.atualizarPet(
      const Pet(id: 11, clienteId: 1, nome: 'Rex'),
    );
    await datasource.removerVeiculo(10);

    expect(veiculo.toEntity().id, 10);
    expect(pet.toEntity().porte, isNull);
    expect(adapter.requisicoes.map((r) => '${r.method} ${r.path}'), [
      'POST veiculos/',
      'PATCH pets/11/',
      'DELETE veiculos/10/',
    ]);
    expect(adapter.requisicoes[0].data, {
      'cliente': 1,
      'placa': 'ABC1D23',
      'marca': 'Fiat',
      'modelo': 'Uno',
      'cor': 'Prata',
    });
    expect((adapter.requisicoes[1].data as Map)['porte'], '');
  });
}
