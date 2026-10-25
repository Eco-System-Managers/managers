import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/onboarding/data/datasources/onboarding_remote_datasource.dart';
import 'package:managers/features/onboarding/data/models/horario_funcionamento_model.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> _configJson({bool concluido = false}) => {
  'id': 1,
  'nome': 'Barbearia Central',
  'telefone': '19999990000',
  'documento': '11222333000181',
  'tipo_documento': 'cnpj',
  'nicho': 'barbearia',
  'nicho_descricao': '',
  'cidade': 'Araras',
  'endereco': 'Rua Um',
  'numero': '10',
  'cep': '13604512',
  'uf': 'SP',
  'tipo_agenda': 'horario',
  'tipo_objeto': '',
  'onboarding_concluido': concluido,
};

Map<String, dynamic> _horarioJson(int dia) => {
  'id': dia + 1,
  'dia': dia,
  'dia_label': 'x',
  'abertura': '09:00:00',
  'fechamento': '18:00:00',
  'ativo': true,
  'capacidade': null,
};

void main() {
  test('buscarConfig lê /empresa/config/', () async {
    final adapter = FakeAdapter((_) async => respostaJson(200, _configJson()));
    final datasource = OnboardingRemoteDataSourceImpl(dioDeTeste(adapter));

    final config = await datasource.buscarConfig();

    expect(adapter.requisicoes.single.method, 'GET');
    expect(adapter.requisicoes.single.path, 'empresa/config/');
    expect(config.nome, 'Barbearia Central');
    expect(config.numero, '10');
    expect(config.tipoAgenda, 'horario');
  });

  test('salvarConfig faz PATCH com o JSON do model', () async {
    final adapter = FakeAdapter((_) async => respostaJson(200, _configJson()));
    final datasource = OnboardingRemoteDataSourceImpl(dioDeTeste(adapter));
    final config = await datasource.buscarConfig();

    await datasource.salvarConfig(config);

    final requisicao = adapter.requisicoes.last;
    expect(requisicao.method, 'PATCH');
    expect(requisicao.path, 'empresa/config/');
    expect((requisicao.data as Map)['nome'], 'Barbearia Central');
    expect((requisicao.data as Map)['numero'], '10');
    expect(
      (requisicao.data as Map).containsKey('onboarding_concluido'),
      isFalse,
    );
  });

  test('buscarHorarios lê o array dos sete dias', () async {
    final adapter = FakeAdapter(
      (_) async =>
          respostaJson(200, [for (var d = 0; d < 7; d++) _horarioJson(d)]),
    );
    final datasource = OnboardingRemoteDataSourceImpl(dioDeTeste(adapter));

    final horarios = await datasource.buscarHorarios();

    expect(adapter.requisicoes.single.path, 'empresa/horarios/');
    expect(horarios.length, 7);
    expect(horarios.first.dia, 0);
    expect(horarios.first.abertura, '09:00:00');
  });

  test(
    'salvarHorarios faz um POST por dia (upsert) e devolve em ordem',
    () async {
      final adapter = FakeAdapter((options) async {
        final dia = (options.data as Map)['dia'] as int;
        // o backend responde 201 ao criar e 200 ao atualizar o mesmo dia
        return respostaJson(dia.isEven ? 201 : 200, _horarioJson(dia));
      });
      final datasource = OnboardingRemoteDataSourceImpl(dioDeTeste(adapter));
      final horarios = [
        for (var d = 6; d >= 0; d--)
          HorarioFuncionamentoModel(
            dia: d,
            ativo: true,
            abertura: '09:00:00',
            fechamento: '18:00:00',
            capacidade: null,
          ),
      ];

      final salvos = await datasource.salvarHorarios(horarios);

      expect(adapter.requisicoes.length, 7);
      expect(adapter.requisicoes.map((r) => r.method).toSet(), {'POST'});
      expect(adapter.requisicoes.map((r) => r.path).toSet(), {
        'empresa/horarios/',
      });
      expect(salvos.map((h) => h.dia), [0, 1, 2, 3, 4, 5, 6]);
    },
  );

  test('concluir faz PATCH só com onboarding_concluido', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, _configJson(concluido: true)),
    );
    final datasource = OnboardingRemoteDataSourceImpl(dioDeTeste(adapter));

    final config = await datasource.concluir();

    expect(adapter.requisicoes.single.method, 'PATCH');
    expect(adapter.requisicoes.single.data, {'onboarding_concluido': true});
    expect(config.onboardingConcluido, isTrue);
  });
}
