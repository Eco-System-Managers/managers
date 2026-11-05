import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tema_controller.dart';
import 'tema_repository.dart';
import 'tema_secure_repository.dart';

// injeção do tema: é o único lugar que conhece a implementação do
// repository. sem autoDispose: o tema vive enquanto o app estiver aberto
final temaRepositoryProvider = Provider<TemaRepository>(
  (ref) => TemaSecureRepository(),
);

final temaControllerProvider = Provider<TemaController>((ref) {
  final controller = TemaController(ref.watch(temaRepositoryProvider));
  ref.onDispose(controller.dispose);
  return controller;
});
