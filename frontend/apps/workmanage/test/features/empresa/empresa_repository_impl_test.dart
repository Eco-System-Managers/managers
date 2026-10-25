import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/cep/via_cep_datasource.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/empresa/data/models/horario_funcionamento_model.dart';
import 'package:managers/features/empresa/domain/entities/horario_funcionamento.dart';
import 'package:managers/features/empresa/data/datasources/empresa_remote_datasource.dart';
import 'package:managers/features/empresa/data/repositories/empresa_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_adapter.dart';

class _MockRemote extends Mock implements EmpresaRemoteDataSource {}

HorarioFuncionamentoModel _dia(int dia, {bool ativo = true}) {
  return HorarioFuncionamentoModel(
    dia: dia,
    ativo: ativo,
    abertura: ativo ? '09:00:00' : null,
    fechamento: ativo ? '17:00:00' : null,
    capacidade: null,
  );
}

void main() {
  late FakeAdapter viaCep;
  late EmpresaRepositoryImpl repository;

  EmpresaRepositoryImpl montar(FakeAdapter adapter) {
    viaCep = adapter;
    return EmpresaRepositoryImpl(
      _MockRemote(),
      ViaCepDataSource(dioDeTeste(adapter)),
    );
  }

  test('CEP encontrado vira a entidade Endereco', () async {
    repository = montar(
      FakeAdapter(
        (_) async => respostaJson(200, {
          'cep': '13604-512',
          'logradouro': 'Rua Um',
          'bairro': 'Centro',
          'localidade': 'Araras',
          'uf': 'SP',
        }),
      ),
    );

    final result = await repository.buscarEnderecoPorCep('13604512');

    final endereco = result.getOrElse(() => throw StateError('falhou'));
    expect(endereco.cep, '13604512');
    expect(endereco.endereco, 'Rua Um');
    expect(endereco.cidade, 'Araras');
    expect(endereco.uf, 'SP');
    expect(viaCep.requisicoes.single.path, '13604512/json/');
  });

  test('CEP inexistente vira NotFoundFailure com code próprio', () async {
    repository = montar(
      FakeAdapter((_) async => respostaJson(200, {'erro': true})),
    );

    final result = await repository.buscarEnderecoPorCep('00000000');

    final failure = result.fold((f) => f, (_) => null);
    expect(failure, isA<NotFoundFailure>());
    expect(failure!.code, 'cep_nao_encontrado');
    expect(failure.message, 'CEP não encontrado.');
  });

  test('ViaCEP fora do ar vira NetworkFailure', () async {
    repository = montar(
      FakeAdapter(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      ),
    );

    final result = await repository.buscarEnderecoPorCep('13604512');

    expect(result.fold((f) => f, (_) => null), isA<NetworkFailure>());
  });

  group('buscarHorarios', () {
    late _MockRemote remote;

    setUp(() {
      remote = _MockRemote();
      repository = EmpresaRepositoryImpl(
        remote,
        ViaCepDataSource(
          dioDeTeste(FakeAdapter((_) async => respostaJson(200, {}))),
        ),
      );
    });

    test('negócio novo, sem dias na API, ganha a semana padrão', () async {
      when(() => remote.buscarHorarios()).thenAnswer((_) async => []);

      final result = await repository.buscarHorarios();

      final semana = result.getOrElse(() => throw StateError('falhou'));
      expect(semana.map((h) => h.dia), DiaSemana.values);
      expect(semana.where((h) => h.ativo).length, 6);
      expect(semana.last.dia, DiaSemana.domingo);
      expect(semana.last.ativo, isFalse);
      expect(semana.first.abertura?.emMinutos, 8 * 60);
      expect(semana.first.fechamento?.emMinutos, 18 * 60);
    });

    test(
      'os dias já salvos prevalecem e os que faltam são completados',
      () async {
        when(() => remote.buscarHorarios())
            .thenAnswer((_) async => [_dia(0), _dia(6, ativo: false), _dia(2)]);

        final result = await repository.buscarHorarios();

        final semana = result.getOrElse(() => throw StateError('falhou'));
        expect(semana.length, 7);
        expect(semana[0].abertura?.emMinutos, 9 * 60);
        expect(semana[2].fechamento?.emMinutos, 17 * 60);
        expect(semana[6].ativo, isFalse);
        expect(semana[1].abertura?.emMinutos, 8 * 60);
      },
    );
  });
}
