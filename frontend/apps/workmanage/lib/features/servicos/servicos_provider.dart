import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/network/dio_client.dart';
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:managers/features/usuarios/usuarios_provider.dart';

import 'data/datasources/servicos_remote_datasource.dart';
import 'data/repositories/servicos_repository_impl.dart';
import 'domain/repositories/servicos_repository.dart';
import 'domain/usecases/alterar_ativo_servico_use_case.dart';
import 'domain/usecases/atualizar_servico_use_case.dart';
import 'domain/usecases/criar_servico_use_case.dart';
import 'domain/usecases/listar_servicos_use_case.dart';
import 'domain/usecases/obter_servico_use_case.dart';
import 'presentation/providers/servico_form_provider.dart';
import 'presentation/providers/servicos_provider.dart';

// injeção de dependências do catálogo: é o único lugar que conhece as
// implementações. trocar a implementação é mexer só aqui
final servicosRemoteDataSourceProvider = Provider<ServicosRemoteDataSource>(
  (ref) => ServicosRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final servicosRepositoryProvider = Provider<ServicosRepository>(
  (ref) => ServicosRepositoryImpl(ref.watch(servicosRemoteDataSourceProvider)),
);

final listarServicosUseCaseProvider = Provider(
  (ref) => ListarServicosUseCase(ref.watch(servicosRepositoryProvider)),
);

final obterServicoUseCaseProvider = Provider(
  (ref) => ObterServicoUseCase(ref.watch(servicosRepositoryProvider)),
);

final criarServicoUseCaseProvider = Provider(
  (ref) => CriarServicoUseCase(ref.watch(servicosRepositoryProvider)),
);

final atualizarServicoUseCaseProvider = Provider(
  (ref) => AtualizarServicoUseCase(ref.watch(servicosRepositoryProvider)),
);

final alterarAtivoServicoUseCaseProvider = Provider(
  (ref) => AlterarAtivoServicoUseCase(ref.watch(servicosRepositoryProvider)),
);

// estado das telas. autoDispose: ao sair da tela, lista e erros somem; a
// próxima abertura recarrega da API
final servicosProvider = Provider.autoDispose<ServicosProvider>((ref) {
  final provider = ServicosProvider(
    listar: ref.watch(listarServicosUseCaseProvider),
    alterarAtivo: ref.watch(alterarAtivoServicoUseCaseProvider),
    negocio: ref.watch(negocioAtualProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

// family: um provider por serviço aberto (null para o novo)
final servicoFormProvider = Provider.autoDispose
    .family<ServicoFormProvider, int?>((ref, id) {
      final provider = ServicoFormProvider(
        id: id,
        obter: ref.watch(obterServicoUseCaseProvider),
        criar: ref.watch(criarServicoUseCaseProvider),
        atualizar: ref.watch(atualizarServicoUseCaseProvider),
        alterarAtivo: ref.watch(alterarAtivoServicoUseCaseProvider),
        listarColaboradores: ref.watch(listarColaboradoresUseCaseProvider),
      );
      ref.onDispose(provider.dispose);
      return provider;
    });
