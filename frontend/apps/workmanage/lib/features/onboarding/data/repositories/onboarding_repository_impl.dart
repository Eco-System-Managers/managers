import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/empresa_config.dart';
import '../../domain/entities/endereco.dart';
import '../../domain/entities/horario_funcionamento.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../datasources/onboarding_remote_datasource.dart';
import '../models/empresa_config_model.dart';
import '../models/horario_funcionamento_model.dart';

// implementa o contrato: chama o datasource, converte model em entidade e
// transforma qualquer erro em Failure. não sabe se o datasource é o
// simulado ou o real
class OnboardingRepositoryImpl implements OnboardingRepository {
  OnboardingRepositoryImpl(this._remoteDataSource);

  final OnboardingRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, EmpresaConfig>> buscarConfig() {
    return _executar(() async {
      final model = await _remoteDataSource.buscarConfig();
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, EmpresaConfig>> salvarConfig(EmpresaConfig config) {
    return _executar(() async {
      final model = await _remoteDataSource.salvarConfig(
        EmpresaConfigModel.fromEntity(config),
      );
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, Endereco>> buscarEnderecoPorCep(String cep) {
    return _executar(() async {
      final model = await _remoteDataSource.buscarEnderecoPorCep(cep);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, List<HorarioFuncionamento>>> buscarHorarios() {
    return _executar(() async {
      final models = await _remoteDataSource.buscarHorarios();
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, List<HorarioFuncionamento>>> salvarHorarios(
    List<HorarioFuncionamento> horarios,
  ) {
    return _executar(() async {
      final models = await _remoteDataSource.salvarHorarios(
        horarios.map(HorarioFuncionamentoModel.fromEntity).toList(),
      );
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, EmpresaConfig>> concluir() {
    return _executar(() async {
      final model = await _remoteDataSource.concluir();
      return model.toEntity();
    });
  }

  // o try/catch é igual em todos os métodos: fica num lugar só
  Future<Either<Failure, T>> _executar<T>(Future<T> Function() acao) async {
    try {
      return Right(await acao());
    } on DioException catch (e) {
      return Left(ServerFailure(_messageFrom(e)));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  // mesma tradução do RegisterRepositoryImpl. as duas cópias devem ir para o
  // core/error quando alguém mexer na register
  String _messageFrom(DioException e) {
    final response = e.response;

    // sem resposta: a requisição nem chegou na API (rede, timeout, URL)
    if (response == null) {
      return 'Não foi possível conectar ao servidor.';
    }

    // contrato de erro da API: {"detail", "code", "fields"?}. em erro de
    // validação o detail é genérico ("Dados inválidos.") e o motivo real
    // fica em fields: {"campo": ["mensagem", ...]}
    final data = response.data;
    if (data is Map) {
      final fields = data['fields'];
      if (fields is Map) {
        for (final value in fields.values) {
          if (value is List && value.isNotEmpty) return value.first.toString();
          if (value is String) return value;
        }
      }

      final detail = data['detail'];
      if (detail is String) return detail;
    }

    return 'Erro no servidor (${response.statusCode}). Tente novamente.';
  }
}
