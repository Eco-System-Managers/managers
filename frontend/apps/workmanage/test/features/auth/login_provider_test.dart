import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao_controller.dart';
import 'package:managers/features/auth/domain/params/login_params.dart';
import 'package:managers/features/auth/domain/usecases/login_use_case.dart';
import 'package:managers/features/auth/presentation/providers/login_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_sessao_repository.dart';

class _MockLoginUseCase extends Mock implements LoginUseCase {}

void main() {
  late _MockLoginUseCase login;
  late SessaoController sessao;
  late LoginProvider provider;

  setUpAll(() {
    registerFallbackValue(const LoginParams(email: '', senha: ''));
  });

  setUp(() {
    login = _MockLoginUseCase();
    sessao = SessaoController(FakeSessaoRepository());
    provider = LoginProvider(login: login, sessao: sessao);
  });

  test('login que dá certo guarda a sessão e devolve true', () async {
    when(() => login(any()))
        .thenAnswer((_) async => const Right(sessaoDeTeste));

    final ok = await provider.login('dono@demo.com', 'SenhaForte123!');

    expect(ok, isTrue);
    expect(sessao.atual, sessaoDeTeste);
    expect(provider.errorMessage, isNull);
    expect(provider.isLoading, isFalse);

    final params = verify(() => login(captureAny())).captured.single;
    expect((params as LoginParams).email, 'dono@demo.com');
    expect(params.senha, 'SenhaForte123!');
  });

  test('login recusado mostra o detail da API e não guarda sessão', () async {
    when(() => login(any())).thenAnswer(
      (_) async => const Left(
        AuthFailure(
          message: 'E-mail ou senha inválidos.',
          code: 'credenciais_invalidas',
        ),
      ),
    );

    final ok = await provider.login('dono@demo.com', 'errada');

    expect(ok, isFalse);
    expect(provider.errorMessage, 'E-mail ou senha inválidos.');
    expect(sessao.autenticado, isFalse);
    expect(provider.isLoading, isFalse);
  });

  test(
    'liga o loading enquanto espera e avisa a tela nas duas pontas',
    () async {
      when(() => login(any()))
          .thenAnswer((_) async => const Right(sessaoDeTeste));
      final estados = <bool>[];
      provider.addListener(() => estados.add(provider.isLoading));

      await provider.login('a@b.c', 'x');

      expect(estados, [true, false]);
    },
  );
}
