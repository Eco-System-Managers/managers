import 'package:dio/dio.dart';
import 'package:managers/core/network/paginacao.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/features/financeiro/data/models/cobranca_model.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';

import '../../domain/entities/pendencia_cobranca.dart';
import '../../domain/entities/slot.dart';
import '../../domain/params/agenda_params.dart';
import '../models/agendamento_model.dart';

// fala com /agendamentos/ e /agenda/ da API. não trata erro: se a
// requisição falhar, a DioException sobe para o repository
abstract class AgendaRemoteDataSource {
  // o dia inteiro, seguindo a paginação. cancelados ficam fora
  Future<List<AgendamentoModel>> listarDoDia(
    DateTime data, {
    int? colaboradorId,
  });

  // todos os agendamentos do cliente (não cancelados), seguindo a paginação
  Future<List<AgendamentoModel>> listarDoCliente(int clienteId);

  Future<AgendamentoModel> obter(int id);

  Future<AgendamentoModel> criar(NovoAgendamentoParams params);

  // PATCH parcial: só o que mudou
  Future<AgendamentoModel> atualizar(int id, Map<String, dynamic> campos);

  Future<AgendamentoModel> cobrar(CobrancaParams params);

  Future<List<Slot>> slots(SlotsParams params);

  // os dias do mês com algum agendamento
  Future<List<DateTime>> diasComRegistro(MesParams params);

  Future<List<PendenciaCobranca>> pendencias();
}

class AgendaRemoteDataSourceImpl implements AgendaRemoteDataSource {
  AgendaRemoteDataSourceImpl(this.dio);

  final Dio dio;

  static const _agendamentos = 'agendamentos/';

  @override
  Future<List<AgendamentoModel>> listarDoDia(
    DateTime data, {
    int? colaboradorId,
  }) {
    return buscarTudo(
      dio,
      _agendamentos,
      query: {'data': dataParaApi(data), 'colaborador': ?colaboradorId},
      item: AgendamentoModel.fromJson,
    );
  }

  @override
  Future<List<AgendamentoModel>> listarDoCliente(int clienteId) {
    return buscarTudo(
      dio,
      _agendamentos,
      query: {'cliente': clienteId},
      item: AgendamentoModel.fromJson,
    );
  }

  @override
  Future<AgendamentoModel> obter(int id) async {
    final response = await dio.get<Map<String, dynamic>>('$_agendamentos$id/');
    return AgendamentoModel.fromJson(response.data!);
  }

  @override
  Future<AgendamentoModel> criar(NovoAgendamentoParams params) async {
    final response = await dio.post<Map<String, dynamic>>(
      _agendamentos,
      data: AgendamentoModel.corpoDeCriacao(params),
    );
    return AgendamentoModel.fromJson(response.data!);
  }

  @override
  Future<AgendamentoModel> atualizar(
    int id,
    Map<String, dynamic> campos,
  ) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '$_agendamentos$id/',
      data: campos,
    );
    return AgendamentoModel.fromJson(response.data!);
  }

  @override
  Future<AgendamentoModel> cobrar(CobrancaParams params) async {
    final response = await dio.post<Map<String, dynamic>>(
      '$_agendamentos${params.id}/cobrar/',
      data: corpoDeCobranca(params),
    );
    return AgendamentoModel.fromJson(response.data!);
  }

  @override
  Future<List<Slot>> slots(SlotsParams params) async {
    final response = await dio.get<List<dynamic>>(
      'agenda/slots/',
      queryParameters: {
        'data': dataParaApi(params.data),
        'servico': params.servicoId,
        'colaborador': params.colaboradorId,
      },
    );
    return [
      for (final s in response.data!.cast<Map<String, dynamic>>())
        Slot(
          hora: horaDaApi(s['horario'] as String),
          disponivel: s['disponivel'] as bool,
        ),
    ];
  }

  @override
  Future<List<DateTime>> diasComRegistro(MesParams params) async {
    final response = await dio.get<List<dynamic>>(
      'agenda/dias-com-registro/',
      queryParameters: {'ano': params.ano, 'mes': params.mes},
    );
    return [for (final d in response.data!) dataDaApi(d as String)];
  }

  @override
  Future<List<PendenciaCobranca>> pendencias() async {
    final response = await dio.get<List<dynamic>>('agenda/pendencias/');
    return [
      for (final p in response.data!.cast<Map<String, dynamic>>())
        PendenciaCobranca(
          origemAgenda: (p['origem'] as String? ?? 'agenda') == 'agenda',
          id: p['id'] as int,
          data: dataDaApi(p['data'] as String),
          clienteId: p['cliente_id'] as int,
          clienteNome: p['cliente_nome'] as String? ?? '',
          servicoNome: p['servico_nome'] as String? ?? '',
          valor: dinheiroDaApi(p['valor'] as String? ?? '0'),
        ),
    ];
  }
}
