import 'package:managers/core/utils/datas.dart';

import '../../domain/entities/bloqueio.dart';
import '../../domain/params/agenda_params.dart';

// o schema Bloqueio do contrato. as horas vêm "12:00:00" ou nulas (o dia
// inteiro); a data de fim nula é o bloqueio fixo; o colaborador nulo é o
// bloqueio do negócio inteiro, e o nome vem nulo junto
class BloqueioModel {
  const BloqueioModel(this.json);

  final Map<String, dynamic> json;

  factory BloqueioModel.fromJson(Map<String, dynamic> json) =>
      BloqueioModel(json);

  Bloqueio toEntity() {
    final dataFim = json['data_fim'] as String?;
    final horaInicio = json['hora_inicio'] as String?;
    final horaFim = json['hora_fim'] as String?;

    return Bloqueio(
      id: json['id'] as int,
      colaboradorId: json['colaborador'] as int?,
      colaboradorNome: json['colaborador_nome'] as String? ?? '',
      dataInicio: dataDaApi(json['data_inicio'] as String),
      dataFim: dataFim == null ? null : dataDaApi(dataFim),
      horaInicio: horaInicio == null ? null : horaDaApi(horaInicio),
      horaFim: horaFim == null ? null : horaDaApi(horaFim),
      motivo: json['motivo'] as String? ?? '',
    );
  }

  // o corpo do POST (BloqueioRequest). o colaborador vai null de propósito
  // no bloqueio do negócio: é assim que a API sabe que é de todos
  static Map<String, dynamic> corpoDeCriacao(NovoBloqueioParams params) {
    final dataFim = params.dataFim;
    final horaInicio = params.horaInicio;
    final horaFim = params.horaFim;
    return {
      'colaborador': params.colaboradorId,
      'data_inicio': dataParaApi(params.dataInicio),
      'data_fim': dataFim == null ? null : dataParaApi(dataFim),
      'hora_inicio': horaInicio == null ? null : horaParaApi(horaInicio),
      'hora_fim': horaFim == null ? null : horaParaApi(horaFim),
      'motivo': params.motivo,
    };
  }
}
