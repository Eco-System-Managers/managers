import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao_controller.dart';
import 'package:managers/features/auth/domain/usecases/logout_use_case.dart';
import 'package:managers/features/home/presentation/providers/mais_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_sessao_repository.dart';

class _MockLogout extends Mock implements LogoutUseCase {}

void main() {
  late _MockLogout logout;
  late SessaoController sessao;
  late MaisProvider mais;

  setUp(() async {
    logout = _MockLogout();
    sessao = SessaoController(FakeSessaoRepository());
    await sessao.entrar(sessaoDeTeste);
    mais = MaisProvider(logout: logout, sessao: sessao);
  });

  test('sair revoga o refresh na API e limpa a sessão', () async {
    when(() => logout(any())).thenAnswer((_) async => const Right(null));

    await mais.sair();

    verify(() => logout(sessaoDeTeste.refresh)).called(1);
    expect(sessao.autenticado, isFalse);
  });

  test('se a API falhar, a sessão local é limpa do mesmo jeito', () async {
    when(() => logout(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));

    await mais.sair();

    expect(sessao.autenticado, isFalse);
  });
}
