import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/network/dio_client.dart';
import 'package:managers/core/session/sessao_provider.dart';

import 'data/datasources/usuarios_remote_datasource.dart';
import 'data/repositories/usuarios_repository_impl.dart';
import 'domain/repositories/usuarios_repository.dart';
import 'domain/usecases/buscar_meu_perfil_use_case.dart';
import 'domain/usecases/equipe_use_cases.dart';
import 'domain/usecases/listar_colaboradores_use_case.dart';
import 'presentation/providers/aceitar_convite_provider.dart';
import 'presentation/providers/colaborador_provider.dart';
import 'presentation/providers/convite_form_provider.dart';
import 'presentation/providers/equipe_provider.dart';

// injeção de dependências da equipe: é o único lugar que conhece as
// implementações. trocar a implementação é mexer só aqui
final usuariosRemoteDataSourceProvider = Provider<UsuariosRemoteDataSource>(
  (ref) => UsuariosRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final usuariosRepositoryProvider = Provider<UsuariosRepository>(
  (ref) => UsuariosRepositoryImpl(ref.watch(usuariosRemoteDataSourceProvider)),
);

final buscarMeuPerfilUseCaseProvider = Provider(
  (ref) => BuscarMeuPerfilUseCase(ref.watch(usuariosRepositoryProvider)),
);

final listarColaboradoresUseCaseProvider = Provider(
  (ref) => ListarColaboradoresUseCase(ref.watch(usuariosRepositoryProvider)),
);

final obterColaboradorUseCaseProvider = Provider(
  (ref) => ObterColaboradorUseCase(ref.watch(usuariosRepositoryProvider)),
);

final atualizarFuncaoUseCaseProvider = Provider(
  (ref) => AtualizarFuncaoUseCase(ref.watch(usuariosRepositoryProvider)),
);

final alterarAtivoColaboradorUseCaseProvider = Provider(
  (ref) =>
      AlterarAtivoColaboradorUseCase(ref.watch(usuariosRepositoryProvider)),
);

final contarAgendamentosPendentesUseCaseProvider = Provider(
  (ref) =>
      ContarAgendamentosPendentesUseCase(ref.watch(usuariosRepositoryProvider)),
);

final removerColaboradorUseCaseProvider = Provider(
  (ref) => RemoverColaboradorUseCase(ref.watch(usuariosRepositoryProvider)),
);

final listarConvitesUseCaseProvider = Provider(
  (ref) => ListarConvitesUseCase(ref.watch(usuariosRepositoryProvider)),
);

final criarConviteUseCaseProvider = Provider(
  (ref) => CriarConviteUseCase(ref.watch(usuariosRepositoryProvider)),
);

final cancelarConviteUseCaseProvider = Provider(
  (ref) => CancelarConviteUseCase(ref.watch(usuariosRepositoryProvider)),
);

final obterConviteUseCaseProvider = Provider(
  (ref) => ObterConviteUseCase(ref.watch(usuariosRepositoryProvider)),
);

final aceitarConviteUseCaseProvider = Provider(
  (ref) => AceitarConviteUseCase(ref.watch(usuariosRepositoryProvider)),
);

// estado das telas. autoDispose: ao sair da tela, lista e erros somem; a
// próxima abertura recarrega da API
final equipeProvider = Provider.autoDispose<EquipeProvider>((ref) {
  final provider = EquipeProvider(
    listarColaboradores: ref.watch(listarColaboradoresUseCaseProvider),
    listarConvites: ref.watch(listarConvitesUseCaseProvider),
    cancelarConvite: ref.watch(cancelarConviteUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

// family: um provider por ficha aberta
final colaboradorProvider = Provider.autoDispose
    .family<ColaboradorProvider, int>((ref, id) {
      final provider = ColaboradorProvider(
        id: id,
        obter: ref.watch(obterColaboradorUseCaseProvider),
        atualizarFuncao: ref.watch(atualizarFuncaoUseCaseProvider),
        alterarAtivo: ref.watch(alterarAtivoColaboradorUseCaseProvider),
        contarPendentes: ref.watch(contarAgendamentosPendentesUseCaseProvider),
        remover: ref.watch(removerColaboradorUseCaseProvider),
      );
      ref.onDispose(provider.dispose);
      return provider;
    });

final conviteFormProvider = Provider.autoDispose<ConviteFormProvider>((ref) {
  final provider = ConviteFormProvider(
    criar: ref.watch(criarConviteUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

// family: o token do link do convite. aceitar entra na sessão
final aceitarConviteProvider = Provider.autoDispose
    .family<AceitarConviteProvider, String>((ref, token) {
      final provider = AceitarConviteProvider(
        token: token,
        obterConvite: ref.watch(obterConviteUseCaseProvider),
        aceitar: ref.watch(aceitarConviteUseCaseProvider),
        sessao: ref.watch(sessaoControllerProvider),
      );
      ref.onDispose(provider.dispose);
      return provider;
    });
