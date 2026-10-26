import 'package:managers/core/utils/datas.dart';

import '../../domain/entities/modelo_contrato.dart';

// o schema ModeloContrato do contrato
class ModeloContratoModel {
  const ModeloContratoModel({
    required this.id,
    required this.titulo,
    required this.corpo,
    required this.ativo,
    this.criadoEm,
  });

  final int id;
  final String titulo;
  final String corpo;
  final bool ativo;
  final String? criadoEm;

  factory ModeloContratoModel.fromJson(Map<String, dynamic> json) {
    return ModeloContratoModel(
      id: json['id'] as int,
      titulo: json['titulo'] as String? ?? '',
      corpo: json['corpo'] as String? ?? '',
      ativo: json['ativo'] as bool? ?? true,
      criadoEm: json['criado_em'] as String?,
    );
  }

  // o id não vai: ele está na URL
  Map<String, dynamic> toJson() => {
    'titulo': titulo,
    'corpo': corpo,
    'ativo': ativo,
  };

  factory ModeloContratoModel.fromEntity(ModeloContrato modelo) {
    return ModeloContratoModel(
      id: modelo.id,
      titulo: modelo.titulo,
      corpo: modelo.corpo,
      ativo: modelo.ativo,
    );
  }

  ModeloContrato toEntity() {
    return ModeloContrato(
      id: id,
      titulo: titulo,
      corpo: corpo,
      ativo: ativo,
      criadoEm: criadoEm == null ? null : dataHoraDaApi(criadoEm!),
    );
  }
}
