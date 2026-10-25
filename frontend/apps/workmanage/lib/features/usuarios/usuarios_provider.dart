import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/network/dio_client.dart';

import 'data/datasources/usuarios_remote_datasource.dart';
import 'data/repositories/usuarios_repository_impl.dart';
import 'domain/repositories/usuarios_repository.dart';
import 'domain/usecases/buscar_meu_perfil_use_case.dart';
import 'domain/usecases/listar_colaboradores_use_case.dart';

// injeção de dependências da equipe: é o único lugar que conhece as
// implementações. a fase 4 completa com convites e ativação
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
