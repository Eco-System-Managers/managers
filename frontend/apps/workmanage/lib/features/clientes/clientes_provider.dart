import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/network/dio_client.dart';
import 'package:managers/features/empresa/empresa_provider.dart';

import 'data/datasources/clientes_remote_datasource.dart';
import 'data/repositories/clientes_repository_impl.dart';
import 'domain/repositories/clientes_repository.dart';
import 'domain/usecases/atualizar_cliente_use_case.dart';
import 'domain/usecases/criar_cliente_use_case.dart';
import 'domain/usecases/listar_clientes_use_case.dart';
import 'domain/usecases/obter_cliente_use_case.dart';
import 'domain/usecases/objetos_use_cases.dart';
import 'domain/usecases/remover_cliente_use_case.dart';
import 'presentation/providers/cliente_form_provider.dart';
import 'presentation/providers/cliente_provider.dart';
import 'presentation/providers/clientes_provider.dart';
import 'presentation/providers/objeto_form_provider.dart';

// injeção de dependências dos clientes: é o único lugar que conhece as
// implementações. trocar a implementação é mexer só aqui
final clientesRemoteDataSourceProvider = Provider<ClientesRemoteDataSource>(
  (ref) => ClientesRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final clientesRepositoryProvider = Provider<ClientesRepository>(
  (ref) => ClientesRepositoryImpl(ref.watch(clientesRemoteDataSourceProvider)),
);

final listarClientesUseCaseProvider = Provider(
  (ref) => ListarClientesUseCase(ref.watch(clientesRepositoryProvider)),
);

final obterClienteUseCaseProvider = Provider(
  (ref) => ObterClienteUseCase(ref.watch(clientesRepositoryProvider)),
);

final criarClienteUseCaseProvider = Provider(
  (ref) => CriarClienteUseCase(ref.watch(clientesRepositoryProvider)),
);

final atualizarClienteUseCaseProvider = Provider(
  (ref) => AtualizarClienteUseCase(ref.watch(clientesRepositoryProvider)),
);

final removerClienteUseCaseProvider = Provider(
  (ref) => RemoverClienteUseCase(ref.watch(clientesRepositoryProvider)),
);

final salvarVeiculoUseCaseProvider = Provider(
  (ref) => SalvarVeiculoUseCase(ref.watch(clientesRepositoryProvider)),
);

final removerVeiculoUseCaseProvider = Provider(
  (ref) => RemoverVeiculoUseCase(ref.watch(clientesRepositoryProvider)),
);

final salvarPetUseCaseProvider = Provider(
  (ref) => SalvarPetUseCase(ref.watch(clientesRepositoryProvider)),
);

final removerPetUseCaseProvider = Provider(
  (ref) => RemoverPetUseCase(ref.watch(clientesRepositoryProvider)),
);

// estado das telas. autoDispose: ao sair da tela, lista e erros somem; a
// próxima abertura recarrega da API
final clientesProvider = Provider.autoDispose<ClientesProvider>((ref) {
  final provider = ClientesProvider(
    listar: ref.watch(listarClientesUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

// family: um provider por ficha aberta
final clienteProvider = Provider.autoDispose.family<ClienteProvider, int>((
  ref,
  id,
) {
  final provider = ClienteProvider(
    id: id,
    obter: ref.watch(obterClienteUseCaseProvider),
    remover: ref.watch(removerClienteUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

// family: um provider por formulário aberto (null para o novo)
final clienteFormProvider = Provider.autoDispose
    .family<ClienteFormProvider, int?>((ref, id) {
      final provider = ClienteFormProvider(
        id: id,
        obter: ref.watch(obterClienteUseCaseProvider),
        criar: ref.watch(criarClienteUseCaseProvider),
        atualizar: ref.watch(atualizarClienteUseCaseProvider),
        buscarEnderecoPorCep: ref.watch(buscarEnderecoPorCepUseCaseProvider),
      );
      ref.onDispose(provider.dispose);
      return provider;
    });

// a folha de veículo ou pet: uma por abertura
final objetoFormProvider = Provider.autoDispose<ObjetoFormProvider>((ref) {
  final provider = ObjetoFormProvider(
    salvarVeiculo: ref.watch(salvarVeiculoUseCaseProvider),
    removerVeiculo: ref.watch(removerVeiculoUseCaseProvider),
    salvarPet: ref.watch(salvarPetUseCaseProvider),
    removerPet: ref.watch(removerPetUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});
