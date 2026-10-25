import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/session/sessao_controller.dart';

import '../../helpers/fake_sessao_repository.dart';

void main() {
  late FakeSessaoRepository repository;
  late SessaoController controller;
  late int notificacoes;

  setUp(() {
    repository = FakeSessaoRepository();
    controller = SessaoController(repository);
    notificacoes = 0;
    controller.addListener(() => notificacoes++);
  });

  test('começa sem sessão e sem ter carregado', () {
    expect(controller.carregada, isFalse);
    expect(controller.autenticado, isFalse);
    expect(controller.atual, isNull);
  });

  test('carregar recupera a sessão guardada', () async {
    repository.guardada = sessaoDeTeste;
    await controller.carregar();
    expect(controller.carregada, isTrue);
    expect(controller.atual, sessaoDeTeste);
    expect(notificacoes, 1);
  });

  test('entrar guarda a sessão e avisa', () async {
    await controller.entrar(sessaoDeTeste);
    expect(repository.guardada, sessaoDeTeste);
    expect(controller.autenticado, isTrue);
    expect(notificacoes, 1);
  });

  test('renovar troca os tokens sem avisar a tela', () async {
    await controller.entrar(sessaoDeTeste);
    await controller.renovar(sessaoRenovada);
    expect(controller.atual, sessaoRenovada);
    expect(repository.guardada, sessaoRenovada);
    expect(notificacoes, 1);
  });

  test('sair limpa a sessão e avisa', () async {
    await controller.entrar(sessaoDeTeste);
    await controller.sair();
    expect(controller.autenticado, isFalse);
    expect(repository.guardada, isNull);
    expect(notificacoes, 2);
  });

  test('sair sem sessão não avisa de novo', () async {
    await controller.sair();
    expect(notificacoes, 0);
  });
}
