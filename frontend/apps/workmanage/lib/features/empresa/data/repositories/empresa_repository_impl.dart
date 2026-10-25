import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:managers/core/cep/via_cep_datasource.dart';
import 'package:managers/core/error/failure_mapper.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/empresa_config.dart';
import '../../domain/entities/endereco.dart';
import '../../domain/entities/horario_funcionamento.dart';
import '../../domain/repositories/empresa_repository.dart';
import '../datasources/empresa_remote_datasource.dart';
import '../models/empresa_config_model.dart';
import '../models/horario_funcionamento_model.dart';

// implementa o contrato: chama os datasources, converte model em entidade e
// transforma qualquer erro em Failure. a config vem da nossa API; o CEP, do
// ViaCEP (core/cep), porque a API não tem busca de endereço
class EmpresaRepositoryImpl implements EmpresaRepository {
  EmpresaRepositoryImpl(this._remoteDataSource, this._cepDataSource);

  final EmpresaRemoteDataSource _remoteDataSource;
  final ViaCepDataSource _cepDataSource;

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
  Future<Either<Failure, Endereco>> buscarEnderecoPorCep(String cep) async {
    try {
      final endereco = await _cepDataSource.buscar(cep);
      return Right(
        Endereco(
          cep: endereco.cep,
          endereco: endereco.logradouro,
          cidade: endereco.cidade,
          uf: endereco.uf,
        ),
      );
    } on CepNaoEncontradoException {
      return const Left(
        NotFoundFailure(
          message: 'CEP não encontrado.',
          code: 'cep_nao_encontrado',
        ),
      );
    } on DioException catch (e) {
      return Left(failureFrom(e));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<HorarioFuncionamento>>> buscarHorarios() {
    return _executar(() async {
      final models = await _remoteDataSource.buscarHorarios();
      return _semanaCompleta(models.map((m) => m.toEntity()).toList());
    });
  }

  // a API só tem os dias que já foram salvos: negócio novo vem sem nenhum.
  // as telas precisam dos sete, então os que faltam entram com um padrão
  // comum (segunda a sábado, 8h às 18h, domingo fechado) para a pessoa
  // ajustar em vez de preencher do zero. só viram linha na API ao salvar
  List<HorarioFuncionamento> _semanaCompleta(
    List<HorarioFuncionamento> salvos,
  ) {
    return [
      for (final dia in DiaSemana.values)
        salvos.firstWhere(
          (h) => h.dia == dia,
          orElse: () => HorarioFuncionamento(
            dia: dia,
            ativo: dia != DiaSemana.domingo,
            abertura: const HoraDoDia(8, 0),
            fechamento: const HoraDoDia(18, 0),
          ),
        ),
    ];
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

  @override
  Future<Either<Failure, String>> enviarLogo(
    List<int> bytes,
    String nomeArquivo,
  ) {
    return _executar(() => _remoteDataSource.enviarLogo(bytes, nomeArquivo));
  }

  // o try/catch é igual em todos os métodos: fica num lugar só. a tradução
  // do erro em Failure é a mesma do app inteiro (core/error/failure_mapper)
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
