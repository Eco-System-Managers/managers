import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/config/env.dart';
import 'package:managers/core/network/dio_client.dart';
import 'package:managers/core/session/sessao_provider.dart';
import 'package:managers/features/auth/auth_provider.dart';

import 'data/datasources/assinatura_remote_datasource.dart';
import 'data/datasources/loja_datasource.dart';
import 'data/repositories/assinatura_repository_impl.dart';
import 'data/repositories/loja_repository_impl.dart';
import 'domain/repositories/assinatura_repository.dart';
import 'domain/repositories/loja_repository.dart';
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

// sem autoDispose: guarda os pacotes da última leitura da loja
final lojaDataSourceProvider = Provider<LojaDataSource>(
  (ref) => LojaRevenueCatDataSource(Env.revenueCatKey),
);

final lojaRepositoryProvider = Provider<LojaRepository>(
  (ref) => LojaRepositoryImpl(ref.watch(lojaDataSourceProvider)),
);

final obterAssinaturaUseCaseProvider = Provider(
  (ref) => ObterAssinaturaUseCase(ref.watch(assinaturaRepositoryProvider)),
);

final listarPagamentosAssinaturaUseCaseProvider = Provider(
  (ref) => ListarPagamentosAssinaturaUseCase(
    ref.watch(assinaturaRepositoryProvider),
  ),
);

final listarOfertasUseCaseProvider = Provider(
  (ref) => ListarOfertasUseCase(ref.watch(lojaRepositoryProvider)),
);

final comprarPlanoUseCaseProvider = Provider(
  (ref) => ComprarPlanoUseCase(
    ref.watch(lojaRepositoryProvider),
    ref.watch(assinaturaRepositoryProvider),
  ),
);

final restaurarComprasUseCaseProvider = Provider(
  (ref) => RestaurarComprasUseCase(
    ref.watch(lojaRepositoryProvider),
    ref.watch(assinaturaRepositoryProvider),
  ),
);

final linkDeGerenciarUseCaseProvider = Provider(
  (ref) => LinkDeGerenciarUseCase(ref.watch(lojaRepositoryProvider)),
);

// autoDispose: a tela recarrega a cada abertura
final assinaturaProvider = Provider.autoDispose<AssinaturaProvider>((ref) {
  final provider = AssinaturaProvider(
    obter: ref.watch(obterAssinaturaUseCaseProvider),
    listarPagamentos: ref.watch(listarPagamentosAssinaturaUseCaseProvider),
    listarOfertas: ref.watch(listarOfertasUseCaseProvider),
    comprar: ref.watch(comprarPlanoUseCaseProvider),
    restaurar: ref.watch(restaurarComprasUseCaseProvider),
    linkDeGerenciar: ref.watch(linkDeGerenciarUseCaseProvider),
    bloqueio: ref.watch(bloqueioAssinaturaProvider),
    logout: ref.watch(logoutUseCaseProvider),
    sessao: ref.watch(sessaoControllerProvider),
    compraNoApp: Env.lojaConfigurada,
  );
  ref.onDispose(provider.dispose);
  return provider;
});
