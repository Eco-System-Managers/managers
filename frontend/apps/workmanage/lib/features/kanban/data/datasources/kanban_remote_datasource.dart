import 'package:dio/dio.dart';
import 'package:managers/core/network/paginacao.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/financeiro/data/models/cobranca_model.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';

import '../../domain/entities/etapa.dart';
import '../../domain/params/kanban_params.dart';
import '../models/kanban_models.dart';

// fala com /kanban/ da API. não trata erro: se a requisição falhar, a
// DioException sobe para o repository
abstract class KanbanRemoteDataSource {
  Future<List<EtapaModel>> listarEtapas();

  Future<EtapaModel> criarEtapa(Etapa etapa);

  Future<EtapaModel> atualizarEtapa(Etapa etapa);

  Future<void> removerEtapa(int id);

  Future<void> reordenarEtapas(List<int> ids);

  Future<EtapaModel> marcarEtapaPronto(int id);

  // o dia inteiro, seguindo a paginação
  Future<List<AtendimentoKanbanModel>> listarDoDia(
    DateTime data, {
    int? colaboradorId,
  });

  Future<List<AtendimentoKanbanModel>> listarDoCliente(int clienteId);

  Future<AtendimentoKanbanModel> obter(int id);

  Future<AtendimentoKanbanModel> criar(NovoAtendimentoParams params);

  Future<AtendimentoKanbanModel> mover(int id, int etapaId);

  Future<AtendimentoKanbanModel> remarcar(
    RemarcarAtendimentoKanbanParams params,
  );

  Future<AtendimentoKanbanModel> ajustarTempo(int id, int minutosExtras);

  Future<AtendimentoKanbanModel> cobrar(CobrancaParams params);

  Future<AtendimentoKanbanModel> desfazerCobranca(int id);

  Future<AtendimentoKanbanModel> marcarFalta(int id);

  Future<AtendimentoKanbanModel> desfazerFalta(int id);

  Future<void> remover(int id);

  // só as horas de entrada livres: a API manda a grade com
  // {horario, disponivel}, como a da agenda, já só com as horas em que o
  // serviço cabe
  Future<List<Hora>> slots(DateTime data, {int? servicoId, int? excluirId});

  Future<CapacidadeDoDiaModel> capacidadeDoDia(DateTime data);

  Future<CapacidadeDoDiaModel> ajustarCapacidade(
    AjustarCapacidadeParams params,
  );

  Future<CapacidadeDoDiaModel> desfazerAjuste(DateTime data);
}

class KanbanRemoteDataSourceImpl implements KanbanRemoteDataSource {
  KanbanRemoteDataSourceImpl(this.dio);

  final Dio dio;

  static const _etapas = 'kanban/etapas/';
  static const _atendimentos = 'kanban/atendimentos/';
  static const _capacidade = 'kanban/capacidade/';

  @override
  Future<List<EtapaModel>> listarEtapas() {
    return buscarTudo(dio, _etapas, item: EtapaModel.fromJson);
  }

  @override
  Future<EtapaModel> criarEtapa(Etapa etapa) async {
    final response = await dio.post<Map<String, dynamic>>(
      _etapas,
      data: EtapaModel.toJson(etapa),
    );
    return EtapaModel.fromJson(response.data!);
  }

  @override
  Future<EtapaModel> atualizarEtapa(Etapa etapa) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '$_etapas${etapa.id}/',
      data: EtapaModel.toJson(etapa),
    );
    return EtapaModel.fromJson(response.data!);
  }

  @override
  Future<void> removerEtapa(int id) async {
    await dio.delete<void>('$_etapas$id/');
  }

  @override
  Future<void> reordenarEtapas(List<int> ids) async {
    await dio.post<void>('${_etapas}reordenar/', data: {'ordem': ids});
  }

  @override
  Future<EtapaModel> marcarEtapaPronto(int id) async {
    final response = await dio.post<Map<String, dynamic>>(
      '$_etapas$id/pronto/',
    );
    return EtapaModel.fromJson(response.data!);
  }

  @override
  Future<List<AtendimentoKanbanModel>> listarDoDia(
    DateTime data, {
    int? colaboradorId,
  }) {
    return buscarTudo(
      dio,
      _atendimentos,
      query: {'data': dataParaApi(data), 'colaborador': ?colaboradorId},
      item: AtendimentoKanbanModel.fromJson,
    );
  }

  @override
  Future<List<AtendimentoKanbanModel>> listarDoCliente(int clienteId) {
    return buscarTudo(
      dio,
      _atendimentos,
      query: {'cliente': clienteId},
      item: AtendimentoKanbanModel.fromJson,
    );
  }

  @override
  Future<AtendimentoKanbanModel> obter(int id) async {
    final response = await dio.get<Map<String, dynamic>>('$_atendimentos$id/');
    return AtendimentoKanbanModel.fromJson(response.data!);
  }

  @override
  Future<AtendimentoKanbanModel> criar(NovoAtendimentoParams params) async {
    final response = await dio.post<Map<String, dynamic>>(
      _atendimentos,
      data: AtendimentoKanbanModel.corpoDeCriacao(params),
    );
    return AtendimentoKanbanModel.fromJson(response.data!);
  }

  @override
  Future<AtendimentoKanbanModel> mover(int id, int etapaId) =>
      _acao(id, 'mover', data: {'etapa_id': etapaId});

  @override
  Future<AtendimentoKanbanModel> remarcar(
    RemarcarAtendimentoKanbanParams params,
  ) => _patch(params.id, AtendimentoKanbanModel.corpoDeRemarcacao(params));

  @override
  Future<AtendimentoKanbanModel> ajustarTempo(int id, int minutosExtras) =>
      _patch(id, {'minutos_extras': minutosExtras});

  @override
  Future<AtendimentoKanbanModel> cobrar(CobrancaParams params) =>
      _acao(params.id, 'cobrar', data: corpoDeCobranca(params));

  @override
  Future<AtendimentoKanbanModel> desfazerCobranca(int id) =>
      _acao(id, 'desfazer_cobranca');

  @override
  Future<AtendimentoKanbanModel> marcarFalta(int id) =>
      _acao(id, 'marcar_falta');

  @override
  Future<AtendimentoKanbanModel> desfazerFalta(int id) =>
      _acao(id, 'desfazer_falta');

  @override
  Future<void> remover(int id) async {
    await dio.delete<void>('$_atendimentos$id/');
  }

  @override
  Future<List<Hora>> slots(
    DateTime data, {
    int? servicoId,
    int? excluirId,
  }) async {
    final response = await dio.get<List<dynamic>>(
      'kanban/slots/',
      queryParameters: {
        'data': dataParaApi(data),
        'servico': ?servicoId,
        'excluir': ?excluirId,
      },
    );
    return [
      for (final s in response.data!.cast<Map<String, dynamic>>())
        if (s['disponivel'] == true) horaDaApi(s['horario'] as String),
    ];
  }

  @override
  Future<CapacidadeDoDiaModel> capacidadeDoDia(DateTime data) async {
    final response = await dio.get<Map<String, dynamic>>(
      _capacidade,
      queryParameters: {'data': dataParaApi(data)},
    );
    return CapacidadeDoDiaModel.fromJson(response.data!);
  }

  @override
  Future<CapacidadeDoDiaModel> ajustarCapacidade(
    AjustarCapacidadeParams params,
  ) async {
    final response = await dio.put<Map<String, dynamic>>(
      _capacidade,
      queryParameters: {'data': dataParaApi(params.data)},
      data: CapacidadeDoDiaModel.corpoDeAjuste(params),
    );
    return CapacidadeDoDiaModel.fromJson(response.data!);
  }

  // a API devolve a capacidade já no padrão; se vier sem corpo (204), lê
  // de novo
  @override
  Future<CapacidadeDoDiaModel> desfazerAjuste(DateTime data) async {
    final response = await dio.delete<dynamic>(
      _capacidade,
      queryParameters: {'data': dataParaApi(data)},
    );
    final json = response.data;
    if (json is Map<String, dynamic> && json.isNotEmpty) {
      return CapacidadeDoDiaModel.fromJson(json);
    }
    return capacidadeDoDia(data);
  }

  // as ações do atendimento são todas POST em kanban/atendimentos/{id}/<acao>/
  Future<AtendimentoKanbanModel> _acao(
    int id,
    String acao, {
    Map<String, dynamic>? data,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '$_atendimentos$id/$acao/',
      data: data,
    );
    return AtendimentoKanbanModel.fromJson(response.data!);
  }

  // remarcar e ajustar o tempo são PATCH no próprio atendimento
  Future<AtendimentoKanbanModel> _patch(
    int id,
    Map<String, dynamic> data,
  ) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '$_atendimentos$id/',
      data: data,
    );
    return AtendimentoKanbanModel.fromJson(response.data!);
  }
}
