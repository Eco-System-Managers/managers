import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/cep/via_cep_datasource.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/onboarding/data/datasources/onboarding_remote_datasource.dart';
import 'package:managers/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_adapter.dart';

class _MockRemote extends Mock implements OnboardingRemoteDataSource {}

void main() {
  late FakeAdapter viaCep;
  late OnboardingRepositoryImpl repository;

  OnboardingRepositoryImpl montar(FakeAdapter adapter) {
    viaCep = adapter;
    return OnboardingRepositoryImpl(
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
}
