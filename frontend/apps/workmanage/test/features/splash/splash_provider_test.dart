import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao_controller.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/empresa/domain/entities/empresa_config.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_config_use_case.dart';
import 'package:managers/features/splash/presentation/providers/splash_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_sessao_repository.dart';

class _MockBuscarConfig extends Mock implements BuscarConfigUseCase {}

void main() {
  late FakeSessaoRepository repository;
  late SessaoController sessao;
  late _MockBuscarConfig buscarConfig;
  late SplashProvider splash;

  setUpAll(() => registerFallbackValue(NoParams()));

  setUp(() {
    repository = FakeSessaoRepository();
    sessao = SessaoController(repository);
    buscarConfig = _MockBuscarConfig();
    splash = SplashProvider(sessao: sessao, buscarConfig: buscarConfig);
  });

  test('sem sessão guardada vai para o login, sem consultar a API', () async {
    await splash.init();
    splash.onAnimationCycleEnd();

    expect(splash.destination, '/login');
    expect(sessao.carregada, isTrue);
    verifyNever(() => buscarConfig(any()));
  });

  test('com sessão e onboarding por concluir vai para o wizard', () async {
    repository.guardada = sessaoDeTeste;
    when(() => buscarConfig(any()))
        .thenAnswer((_) async => const Right(EmpresaConfig()));

    await splash.init();
    splash.onAnimationCycleEnd();

    expect(splash.destination, '/onboarding');
    expect(sessao.atual, sessaoDeTeste);
  });

  test('com sessão e onboarding concluído vai para a home', () async {
    repository.guardada = sessaoDeTeste;
    when(() => buscarConfig(any())).thenAnswer(
      (_) async => const Right(EmpresaConfig(onboardingConcluido: true)),
    );

    await splash.init();
    splash.onAnimationCycleEnd();

    expect(splash.destination, '/home');
  });

  test('sessão que a API não aceita mais leva ao login', () async {
    repository.guardada = sessaoDeTeste;
    when(() => buscarConfig(any())).thenAnswer(
      (_) async => const Left(AuthFailure(code: 'inactivity_timeout')),
    );

    await splash.init();
    splash.onAnimationCycleEnd();

    expect(splash.destination, '/login');
  });

  test('API fora do ar com sessão válida abre a home mesmo assim', () async {
    repository.guardada = sessaoDeTeste;
    when(() => buscarConfig(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));

    await splash.init();
    splash.onAnimationCycleEnd();

    expect(splash.destination, '/home');
  });

  test('só decide depois de um ciclo da animação', () async {
    await splash.init();

    expect(splash.rotaDecidida, isTrue);
    expect(splash.destination, isNull);
    splash.onAnimationCycleEnd();
    expect(splash.destination, '/login');
  });

  test('rota decidida no meio de um ciclo espera o fim desse ciclo', () async {
    // o primeiro ciclo acaba antes da decisão: nada a fazer ainda
    splash.onAnimationCycleEnd();
    expect(splash.rotaDecidida, isFalse);
    expect(splash.destination, isNull);

    // a decisão chega com a animação no meio do ciclo seguinte
    await splash.init();
    expect(splash.rotaDecidida, isTrue);
    expect(splash.destination, isNull);

    // só o fim desse ciclo libera a navegação
    splash.onAnimationCycleEnd();
    expect(splash.destination, '/login');
  });

  test('avisa a tela quando a rota é decidida e quando libera', () async {
    var avisos = 0;
    splash.addListener(() => avisos++);

    await splash.init();
    expect(avisos, 1);
    splash.onAnimationCycleEnd();
    expect(avisos, 2);
    // fins de ciclo depois disso não avisam de novo
    splash.onAnimationCycleEnd();
    expect(avisos, 2);
  });
}
