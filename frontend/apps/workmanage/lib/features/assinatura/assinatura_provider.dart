import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/network/dio_client.dart';
import 'package:managers/core/session/sessao_provider.dart';
import 'package:managers/features/auth/auth_provider.dart';

import 'data/datasources/assinatura_remote_datasource.dart';
import 'data/repositories/assinatura_repository_impl.dart';
import 'domain/repositories/assinatura_repository.dart';
import 'domain/usecases/assinatura_use_cases.dart';
import 'presentation/providers/assinatura_provider.dart';

// injeção de dependências da assinatura: é o único lugar que conhece as
// implementações
final assinaturaRemoteDataSourceProvider = Provider<AssinaturaRemoteDataSource>(
  (ref) => AssinaturaRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final assinaturaRepositoryProvider = Provider<AssinaturaRepository>(
  (ref) =>
      AssinaturaRepositoryImpl(ref.watch(assinaturaRemoteDataSourceProvider)),
);

final obterAssinaturaUseCaseProvider = Provider(
  (ref) => ObterAssinaturaUseCase(ref.watch(assinaturaRepositoryProvider)),
);

final iniciarAssinaturaUseCaseProvider = Provider(
  (ref) => IniciarAssinaturaUseCase(ref.watch(assinaturaRepositoryProvider)),
);

final confirmarAssinaturaUseCaseProvider = Provider(
  (ref) => ConfirmarAssinaturaUseCase(ref.watch(assinaturaRepositoryProvider)),
);

final cancelarAssinaturaUseCaseProvider = Provider(
  (ref) => CancelarAssinaturaUseCase(ref.watch(assinaturaRepositoryProvider)),
);

final listarPagamentosAssinaturaUseCaseProvider = Provider(
  (ref) => ListarPagamentosAssinaturaUseCase(
    ref.watch(assinaturaRepositoryProvider),
  ),
);

// autoDispose: a tela recarrega a cada abertura
final assinaturaProvider = Provider.autoDispose<AssinaturaProvider>((ref) {
  final provider = AssinaturaProvider(
    obter: ref.watch(obterAssinaturaUseCaseProvider),
    iniciar: ref.watch(iniciarAssinaturaUseCaseProvider),
    confirmar: ref.watch(confirmarAssinaturaUseCaseProvider),
    cancelar: ref.watch(cancelarAssinaturaUseCaseProvider),
    listarPagamentos: ref.watch(listarPagamentosAssinaturaUseCaseProvider),
    bloqueio: ref.watch(bloqueioAssinaturaProvider),
    logout: ref.watch(logoutUseCaseProvider),
    sessao: ref.watch(sessaoControllerProvider),
    compraNoApp: defaultTargetPlatform != TargetPlatform.iOS,
  );
  ref.onDispose(provider.dispose);
  return provider;
});
