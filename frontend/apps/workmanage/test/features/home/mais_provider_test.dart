import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao_controller.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/assinatura/domain/entities/assinatura.dart';
import 'package:managers/features/assinatura/domain/usecases/assinatura_use_cases.dart';
import 'package:managers/features/auth/domain/usecases/logout_use_case.dart';
import 'package:managers/features/home/presentation/providers/mais_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_sessao_repository.dart';

class _MockLogout extends Mock implements LogoutUseCase {}

class _MockObterAssinatura extends Mock implements ObterAssinaturaUseCase {}

Assinatura _assinatura({required bool checkoutAberto}) => Assinatura(
  status: StatusAssinatura.trial,
  planoNome: 'Pro',
  inicio: DateTime(2026, 10, 1),
  proximoVencimento: DateTime(2026, 11, 1),
  bloqueada: false,
  checkoutAberto: checkoutAberto,
);

void main() {
  late _MockLogout logout;
  late SessaoController sessao;
  late _MockObterAssinatura obterAssinatura;
  late MaisProvider mais;

  setUpAll(() => registerFallbackValue(NoParams()));

  setUp(() async {
    logout = _MockLogout();
    obterAssinatura = _MockObterAssinatura();
    sessao = SessaoController(FakeSessaoRepository());
    await sessao.entrar(sessaoDeTeste);
    mais = MaisProvider(
      logout: logout,
      sessao: sessao,
      obterAssinatura: obterAssinatura,
    );
  });

  group('item da assinatura', () {
    test('fica escondido antes de carregar', () {
      expect(mais.mostraAssinatura, isFalse);
    });

    test('some com o checkout fechado (fase de testes)', () async {
      when(() => obterAssinatura(any()))
          .thenAnswer((_) async => Right(_assinatura(checkoutAberto: false)));

      await mais.carregar();

      expect(mais.mostraAssinatura, isFalse);
    });

    test('aparece com o checkout aberto', () async {
      when(() => obterAssinatura(any()))
          .thenAnswer((_) async => Right(_assinatura(checkoutAberto: true)));

      await mais.carregar();

      expect(mais.mostraAssinatura, isTrue);
    });

    test('fica escondido se a API falhar', () async {
      when(() => obterAssinatura(any()))
          .thenAnswer((_) async => const Left(NetworkFailure()));

      await mais.carregar();

      expect(mais.mostraAssinatura, isFalse);
    });

    test('no iPhone nunca aparece, nem pergunta à API', () async {
      final iphone = MaisProvider(
        logout: logout,
        sessao: sessao,
        obterAssinatura: obterAssinatura,
        compraNoApp: false,
      );

      await iphone.carregar();

      expect(iphone.mostraAssinatura, isFalse);
      verifyNever(() => obterAssinatura(any()));
    });
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
