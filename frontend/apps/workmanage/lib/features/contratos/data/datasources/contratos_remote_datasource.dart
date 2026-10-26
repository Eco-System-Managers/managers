import 'package:dio/dio.dart';
import 'package:managers/core/network/paginacao.dart';

import '../models/contrato_model.dart';
import '../models/modelo_contrato_model.dart';

// fala com /contratos/ e /contratos/modelos/ da API e devolve models. não
// trata erro: se a requisição falhar, a DioException sobe para o repository
abstract class ContratosRemoteDataSource {
  // as listas são paginadas na API; aqui vêm inteiras (são pequenas)
  Future<List<ModeloContratoModel>> listarModelos({bool? ativo});
  Future<ModeloContratoModel> obterModelo(int id);
  Future<ModeloContratoModel> criarModelo(ModeloContratoModel modelo);
  Future<ModeloContratoModel> atualizarModelo(
    int id,
    ModeloContratoModel modelo,
  );

  // inativar e reativar são um PATCH só no ativo. o DELETE apaga de verdade
  // e solta os contratos já gerados do modelo, por isso não é usado
  Future<ModeloContratoModel> alterarAtivoModelo(int id, bool ativo);

  Future<List<ContratoModel>> listarContratos({int? clienteId, String? status});
  Future<ContratoModel> obterContrato(int id);
  Future<ContratoModel> gerar({required int modeloId, required int clienteId});
  Future<ContratoModel> marcar(int id, String status, {String nomeAssinante});
  Future<void> removerContrato(int id);
}

class ContratosRemoteDataSourceImpl implements ContratosRemoteDataSource {
  ContratosRemoteDataSourceImpl(this.dio);

  final Dio dio;

  static const _contratos = 'contratos/';
  static const _modelos = 'contratos/modelos/';

  @override
  Future<List<ModeloContratoModel>> listarModelos({bool? ativo}) {
    return buscarTudo(
      dio,
      _modelos,
      query: {if (ativo != null) 'ativo': ativo.toString()},
      item: ModeloContratoModel.fromJson,
    );
  }

  @override
  Future<ModeloContratoModel> obterModelo(int id) async {
    final response = await dio.get<Map<String, dynamic>>('$_modelos$id/');
    return ModeloContratoModel.fromJson(response.data!);
  }

  @override
  Future<ModeloContratoModel> criarModelo(ModeloContratoModel modelo) async {
    final response = await dio.post<Map<String, dynamic>>(
      _modelos,
      data: modelo.toJson(),
    );
    return ModeloContratoModel.fromJson(response.data!);
  }

  @override
  Future<ModeloContratoModel> atualizarModelo(
    int id,
    ModeloContratoModel modelo,
  ) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '$_modelos$id/',
      data: modelo.toJson(),
    );
    return ModeloContratoModel.fromJson(response.data!);
  }

  @override
  Future<ModeloContratoModel> alterarAtivoModelo(int id, bool ativo) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '$_modelos$id/',
      data: {'ativo': ativo},
    );
    return ModeloContratoModel.fromJson(response.data!);
  }

  @override
  Future<List<ContratoModel>> listarContratos({
    int? clienteId,
    String? status,
  }) {
    return buscarTudo(
      dio,
      _contratos,
      query: {'cliente': ?clienteId, 'status': ?status},
      item: ContratoModel.fromJson,
    );
  }

  @override
  Future<ContratoModel> obterContrato(int id) async {
    final response = await dio.get<Map<String, dynamic>>('$_contratos$id/');
    return ContratoModel.fromJson(response.data!);
  }

  @override
  Future<ContratoModel> gerar({
    required int modeloId,
    required int clienteId,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '${_contratos}gerar/',
      data: {'modelo_id': modeloId, 'cliente_id': clienteId},
    );
    return ContratoModel.fromJson(response.data!);
  }

  @override
  Future<ContratoModel> marcar(
    int id,
    String status, {
    String nomeAssinante = '',
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '$_contratos$id/marcar/',
      data: {
        'status': status,
        if (nomeAssinante.isNotEmpty) 'nome_assinante': nomeAssinante,
      },
    );
    return ContratoModel.fromJson(response.data!);
  }

  @override
  Future<void> removerContrato(int id) => dio.delete<void>('$_contratos$id/');
}
