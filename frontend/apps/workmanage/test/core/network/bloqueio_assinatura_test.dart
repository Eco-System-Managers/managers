import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/network/auth_interceptor.dart';
import 'package:managers/core/session/bloqueio_assinatura.dart';
import 'package:managers/core/session/sessao_controller.dart';
import 'package:managers/core/session/sessao_provider.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/fake_sessao_repository.dart';

void main() {
  test('402 marca o bloqueio com o detail e mantém a sessão', () async {
    final sessao = SessaoController(FakeSessaoRepository());
    await sessao.entrar(sessaoDeTeste);
    final bloqueio = BloqueioAssinatura();
    final api = FakeAdapter(
      (_) async => respostaErro(
        402,
        'assinatura_bloqueada',
        detail: 'Assinatura inativa. Assine um plano para continuar.',
      ),
    );
    final dio = dioDeTeste(api);
    dio.interceptors.add(
      AuthInterceptor(
        sessao: sessao,
        dio: dio,
        dioRenovacao: dioDeTeste(api),
        bloqueio: bloqueio,
      ),
    );

    // o erro segue para quem chamou: a tela mostra a mensagem
    await expectLater(dio.get('clientes/'), throwsA(isA<DioException>()));

    expect(bloqueio.bloqueada, isTrue);
    expect(
      bloqueio.mensagem,
      'Assinatura inativa. Assine um plano para continuar.',
    );
    expect(sessao.autenticado, isTrue);
  });

  test('o bloqueio some quando a sessão acaba', () async {
    final container = ProviderContainer(
      overrides: [
        sessaoRepositoryProvider.overrideWithValue(FakeSessaoRepository()),
      ],
    );
    addTearDown(container.dispose);
    final sessao = container.read(sessaoControllerProvider);
    final bloqueio = container.read(bloqueioAssinaturaProvider);
    await sessao.entrar(sessaoDeTeste);
    bloqueio.marcar('Assinatura inativa.');

    await sessao.sair();

    expect(bloqueio.bloqueada, isFalse);
  });

  test('marcar e limpar avisam quem escuta só quando algo muda', () {
    final bloqueio = BloqueioAssinatura();
    var avisos = 0;
    bloqueio.addListener(() => avisos++);

    bloqueio.marcar('a');
    bloqueio.marcar('a');
    bloqueio.limpar();
    bloqueio.limpar();

    expect(avisos, 2);
  });
}
