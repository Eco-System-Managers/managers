import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bloqueio_assinatura.dart';
import 'sessao_controller.dart';
import 'sessao_repository.dart';
import 'sessao_secure_repository.dart';

// injeção da sessão: é o único lugar que conhece a implementação do
// repository. sem autoDispose: a sessão vive enquanto o app estiver aberto
final sessaoRepositoryProvider = Provider<SessaoRepository>(
  (ref) => SessaoSecureRepository(),
);

final sessaoControllerProvider = Provider<SessaoController>((ref) {
  final controller = SessaoController(ref.watch(sessaoRepositoryProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

// o aviso de assinatura bloqueada (402) vive junto com a sessão e acaba
// com ela: o próximo negócio que entrar não herda o bloqueio do anterior
final bloqueioAssinaturaProvider = Provider<BloqueioAssinatura>((ref) {
  final sessao = ref.watch(sessaoControllerProvider);
  final bloqueio = BloqueioAssinatura();
  void aoMudarSessao() {
    if (!sessao.autenticado) bloqueio.limpar();
  }

  sessao.addListener(aoMudarSessao);
  ref.onDispose(() {
    sessao.removeListener(aoMudarSessao);
    bloqueio.dispose();
  });
  return bloqueio;
});
