import 'package:flutter_riverpod/flutter_riverpod.dart';

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
