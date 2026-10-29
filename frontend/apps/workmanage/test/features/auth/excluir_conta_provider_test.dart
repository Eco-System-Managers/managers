import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao_controller.dart';
import 'package:managers/features/auth/domain/usecases/excluir_conta_use_case.dart';
import 'package:managers/features/auth/presentation/providers/excluir_conta_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_sessao_repository.dart';

class _MockExcluirConta extends Mock implements ExcluirContaUseCase {}

void main() {
  late _MockExcluirConta excluir;
  late SessaoController sessao;
  late ExcluirContaProvider provider;

  setUp(() async {
    excluir = _MockExcluirConta();
    sessao = SessaoController(FakeSessaoRepository());
    await sessao.entrar(sessaoDeTeste);
    provider = ExcluirContaProvider(excluir: excluir, sessao: sessao);
  });

  test('deu certo: a sessão acaba', () async {
    when(() => excluir('SenhaForte123!'))
        .thenAnswer((_) async => const Right(null));

    await provider.excluir('SenhaForte123!');

    expect(sessao.atual, isNull);
    expect(provider.errorMessage, isNull);
  });

  test('senha errada vai para o campo e a sessão fica', () async {
    when(() => excluir('errada')).thenAnswer(
      (_) async => const Left(
        ServerFailure(message: 'Senha incorreta.', code: 'senha_incorreta'),
      ),
    );

    await provider.excluir('errada');

    expect(provider.erroSenha, 'Senha incorreta.');
    expect(provider.errorMessage, isNull);
    expect(sessao.atual, sessaoDeTeste);

    provider.limparErroSenha();
    expect(provider.erroSenha, isNull);
  });

  test('outro erro vira mensagem da tela', () async {
    when(() => excluir(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'Não foi possível cancelar a assinatura.',
          code: 'assinatura_nao_cancelada',
        ),
      ),
    );

    await provider.excluir('SenhaForte123!');

    expect(provider.errorMessage, 'Não foi possível cancelar a assinatura.');
    expect(provider.isLoading, isFalse);
    expect(sessao.atual, sessaoDeTeste);
  });
}
