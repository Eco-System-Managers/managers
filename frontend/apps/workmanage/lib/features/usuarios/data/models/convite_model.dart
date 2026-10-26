import 'package:managers/core/utils/datas.dart';

import '../../domain/entities/convite.dart';

// os schemas ConviteColaborador e ConviteInfo do contrato
class ConviteModel {
  const ConviteModel(this.json);

  final Map<String, dynamic> json;

  factory ConviteModel.fromJson(Map<String, dynamic> json) =>
      ConviteModel(json);

  Convite toEntity() {
    return Convite(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
      email: json['email'] as String? ?? '',
      aceito: json['aceito'] as bool? ?? false,
      criadoEm: dataHoraDaApi(json['criado_em'] as String),
      expiraEm: dataHoraDaApi(json['expira_em'] as String),
      colaboradorId: json['colaborador'] as int?,
      link: json['link'] as String? ?? '',
    );
  }
}

class ConviteInfoModel {
  const ConviteInfoModel(this.json);

  final Map<String, dynamic> json;

  factory ConviteInfoModel.fromJson(Map<String, dynamic> json) =>
      ConviteInfoModel(json);

  ConviteInfo toEntity() {
    return ConviteInfo(
      nome: json['nome'] as String? ?? '',
      email: json['email'] as String? ?? '',
      expiraEm: dataHoraDaApi(json['expira_em'] as String),
    );
  }
}
