import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:managers/core/error/failure_mapper.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao.dart';

import '../../domain/entities/colaborador.dart';
import '../../domain/entities/convite.dart';
import '../../domain/params/equipe_params.dart';
import '../../domain/repositories/usuarios_repository.dart';
import '../datasources/usuarios_remote_datasource.dart';

// implementa o contrato: chama o datasource, converte model em entidade e
// transforma qualquer erro em Failure
class UsuariosRepositoryImpl implements UsuariosRepository {
  UsuariosRepositoryImpl(this._remoteDataSource);

  final UsuariosRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, Colaborador>> buscarMeuPerfil() {
    return _executar(() async {
      final model = await _remoteDataSource.meuPerfil();
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, List<Colaborador>>> listarColaboradores({
    String? busca,
  }) {
    return _executar(() async {
      final models = await _remoteDataSource.listar(busca: busca);
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, Colaborador>> obterColaborador(int id) {
    return _executar(
      () async => (await _remoteDataSource.obter(id)).toEntity(),
    );
  }

  @override
  Future<Either<Failure, Colaborador>> criarColaborador(
    DadosColaborador dados,
  ) {
    return _executar(
      () async => (await _remoteDataSource.criar(dados)).toEntity(),
    );
  }

  @override
  Future<Either<Failure, Colaborador>> atualizarColaborador(
    int id,
    DadosColaborador dados,
  ) {
    return _executar(
      () async => (await _remoteDataSource.atualizar(id, dados)).toEntity(),
    );
  }

  @override
  Future<Either<Failure, Convite>> convidarColaborador(int id, String email) {
    return _executar(
      () async => (await _remoteDataSource.convidar(id, email)).toEntity(),
    );
  }

  @override
  Future<Either<Failure, void>> ativarColaborador(int id) {
    return _executar(() => _remoteDataSource.ativar(id));
  }

  @override
  Future<Either<Failure, void>> desativarColaborador(int id) {
    return _executar(() => _remoteDataSource.desativar(id));
  }

  @override
  Future<Either<Failure, int>> contarAgendamentosPendentes(int id) {
    return _executar(() => _remoteDataSource.agendamentosPendentes(id));
  }

  @override
  Future<Either<Failure, void>> removerColaborador(int id) {
    return _executar(() => _remoteDataSource.remover(id));
  }

  @override
  Future<Either<Failure, List<Convite>>> listarConvites() {
    return _executar(() async {
      final models = await _remoteDataSource.listarConvites();
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, Convite>> criarConvite({
    required String nome,
    required String email,
  }) {
    return _executar(() async {
      final model = await _remoteDataSource.criarConvite(
        nome: nome,
        email: email,
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> cancelarConvite(int id) {
    return _executar(() => _remoteDataSource.cancelarConvite(id));
  }

  @override
  Future<Either<Failure, ConviteInfo>> obterConvite(String token) {
    return _executar(() async {
      final model = await _remoteDataSource.infoConvite(token);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, Sessao>> aceitarConvite({
    required String token,
    required String senha,
  }) {
    return _executar(() async {
      final model = await _remoteDataSource.aceitarConvite(
        token: token,
        senha: senha,
      );
      return model.toEntity();
    });
  }

  // o try/catch é igual em todos os métodos: fica num lugar só
  Future<Either<Failure, T>> _executar<T>(Future<T> Function() acao) async {
    try {
      return Right(await acao());
    } on DioException catch (e) {
      return Left(failureFrom(e));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }
}
