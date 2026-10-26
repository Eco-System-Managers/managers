import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';

import '../entities/contrato.dart';
import '../entities/modelo_contrato.dart';

abstract class ContratosRepository {
  // sem o filtro vêm todos; true só os ativos (para gerar)
  Future<Either<Failure, List<ModeloContrato>>> listarModelos({bool? ativo});
  Future<Either<Failure, ModeloContrato>> obterModelo(int id);
  Future<Either<Failure, ModeloContrato>> criarModelo(ModeloContrato modelo);
  Future<Either<Failure, ModeloContrato>> atualizarModelo(
    ModeloContrato modelo,
  );
  Future<Either<Failure, ModeloContrato>> alterarAtivoModelo(
    int id,
    bool ativo,
  );

  Future<Either<Failure, List<Contrato>>> listarContratos({
    int? clienteId,
    StatusContrato? status,
  });
  Future<Either<Failure, Contrato>> obterContrato(int id);
  Future<Either<Failure, Contrato>> gerar({
    required int modeloId,
    required int clienteId,
  });
  Future<Either<Failure, Contrato>> marcar(
    int id,
    StatusContrato status, {
    String nomeAssinante = '',
  });
  Future<Either<Failure, void>> removerContrato(int id);
}
