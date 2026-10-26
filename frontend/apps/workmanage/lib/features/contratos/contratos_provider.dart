import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/network/dio_client.dart';
import 'package:managers/features/clientes/clientes_provider.dart';
import 'package:managers/features/empresa/empresa_provider.dart';

import 'data/datasources/contratos_remote_datasource.dart';
import 'data/repositories/contratos_repository_impl.dart';
import 'domain/repositories/contratos_repository.dart';
import 'domain/usecases/contratos_use_cases.dart';
import 'domain/usecases/modelos_use_cases.dart';
import 'presentation/providers/contrato_provider.dart';
import 'presentation/providers/contratos_cliente_provider.dart';
import 'presentation/providers/contratos_provider.dart';
import 'presentation/providers/gerar_contrato_provider.dart';
import 'presentation/providers/modelo_form_provider.dart';
import 'presentation/providers/modelos_provider.dart';

// injeção de dependências dos contratos: é o único lugar que conhece as
// implementações. trocar a implementação é mexer só aqui
final contratosRemoteDataSourceProvider = Provider<ContratosRemoteDataSource>(
  (ref) => ContratosRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final contratosRepositoryProvider = Provider<ContratosRepository>(
  (ref) =>
      ContratosRepositoryImpl(ref.watch(contratosRemoteDataSourceProvider)),
);

final listarModelosUseCaseProvider = Provider(
  (ref) => ListarModelosUseCase(ref.watch(contratosRepositoryProvider)),
);

final obterModeloUseCaseProvider = Provider(
  (ref) => ObterModeloUseCase(ref.watch(contratosRepositoryProvider)),
);

final criarModeloUseCaseProvider = Provider(
  (ref) => CriarModeloUseCase(ref.watch(contratosRepositoryProvider)),
);

final atualizarModeloUseCaseProvider = Provider(
  (ref) => AtualizarModeloUseCase(ref.watch(contratosRepositoryProvider)),
);

final alterarAtivoModeloUseCaseProvider = Provider(
  (ref) => AlterarAtivoModeloUseCase(ref.watch(contratosRepositoryProvider)),
);

final listarContratosUseCaseProvider = Provider(
  (ref) => ListarContratosUseCase(ref.watch(contratosRepositoryProvider)),
);

final obterContratoUseCaseProvider = Provider(
  (ref) => ObterContratoUseCase(ref.watch(contratosRepositoryProvider)),
);

final gerarContratoUseCaseProvider = Provider(
  (ref) => GerarContratoUseCase(ref.watch(contratosRepositoryProvider)),
);

final marcarContratoUseCaseProvider = Provider(
  (ref) => MarcarContratoUseCase(ref.watch(contratosRepositoryProvider)),
);

final removerContratoUseCaseProvider = Provider(
  (ref) => RemoverContratoUseCase(ref.watch(contratosRepositoryProvider)),
);

// estado das telas. autoDispose: ao sair da tela, lista e erros somem; a
// próxima abertura recarrega da API
final modelosProvider = Provider.autoDispose<ModelosProvider>((ref) {
  final provider = ModelosProvider(
    listar: ref.watch(listarModelosUseCaseProvider),
    alterarAtivo: ref.watch(alterarAtivoModeloUseCaseProvider),
    negocio: ref.watch(negocioAtualProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

// family: um provider por modelo aberto (null para o novo)
final modeloFormProvider = Provider.autoDispose
    .family<ModeloFormProvider, int?>((ref, id) {
      final provider = ModeloFormProvider(
        id: id,
        obter: ref.watch(obterModeloUseCaseProvider),
        criar: ref.watch(criarModeloUseCaseProvider),
        atualizar: ref.watch(atualizarModeloUseCaseProvider),
        alterarAtivo: ref.watch(alterarAtivoModeloUseCaseProvider),
      );
      ref.onDispose(provider.dispose);
      return provider;
    });

final contratosProvider = Provider.autoDispose<ContratosProvider>((ref) {
  final provider = ContratosProvider(
    listar: ref.watch(listarContratosUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

// family: um provider por ficha aberta
final contratoProvider = Provider.autoDispose.family<ContratoProvider, int>((
  ref,
  id,
) {
  final provider = ContratoProvider(
    id: id,
    obter: ref.watch(obterContratoUseCaseProvider),
    marcar: ref.watch(marcarContratoUseCaseProvider),
    remover: ref.watch(removerContratoUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

// family: o cliente que já vem escolhido (null quando se escolhe na tela)
final gerarContratoProvider = Provider.autoDispose
    .family<GerarContratoProvider, int?>((ref, clienteId) {
      final provider = GerarContratoProvider(
        clienteInicialId: clienteId,
        listarModelos: ref.watch(listarModelosUseCaseProvider),
        listarClientes: ref.watch(listarClientesUseCaseProvider),
        obterCliente: ref.watch(obterClienteUseCaseProvider),
        gerar: ref.watch(gerarContratoUseCaseProvider),
      );
      ref.onDispose(provider.dispose);
      return provider;
    });

// family: um provider por ficha de cliente aberta
final contratosClienteProvider = Provider.autoDispose
    .family<ContratosClienteProvider, int>((ref, clienteId) {
      final provider = ContratosClienteProvider(
        clienteId: clienteId,
        listar: ref.watch(listarContratosUseCaseProvider),
      );
      ref.onDispose(provider.dispose);
      return provider;
    });
