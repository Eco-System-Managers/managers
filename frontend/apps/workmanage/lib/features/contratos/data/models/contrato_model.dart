import 'package:managers/core/utils/datas.dart';

import '../../domain/entities/contrato.dart';

// o schema Contrato do contrato: só leitura, o app nunca manda um inteiro
class ContratoModel {
  const ContratoModel({
    required this.id,
    this.modelo,
    required this.cliente,
    required this.clienteNome,
    required this.clienteEmail,
    required this.titulo,
    required this.corpo,
    required this.status,
    required this.nomeAssinante,
    this.assinadoEm,
    required this.criadoEm,
  });

  final int id;
  final int? modelo;
  final int cliente;
  final String clienteNome;
  final String clienteEmail;
  final String titulo;
  final String corpo;
  final String status;
  final String nomeAssinante;
  final String? assinadoEm;
  final String criadoEm;

  factory ContratoModel.fromJson(Map<String, dynamic> json) {
    return ContratoModel(
      id: json['id'] as int,
      modelo: json['modelo'] as int?,
      cliente: json['cliente'] as int,
      clienteNome: json['cliente_nome'] as String? ?? '',
      clienteEmail: json['cliente_email'] as String? ?? '',
      titulo: json['titulo'] as String? ?? '',
      corpo: json['corpo'] as String? ?? '',
      status: json['status'] as String? ?? 'pendente',
      nomeAssinante: json['nome_assinante'] as String? ?? '',
      assinadoEm: json['assinado_em'] as String?,
      criadoEm: json['criado_em'] as String,
    );
  }

  Contrato toEntity() {
    return Contrato(
      id: id,
      modeloId: modelo,
      clienteId: cliente,
      clienteNome: clienteNome,
      clienteEmail: clienteEmail,
      titulo: titulo,
      corpo: corpo,
      status: StatusContrato.daApi(status),
      nomeAssinante: nomeAssinante,
      assinadoEm: assinadoEm == null ? null : dataHoraDaApi(assinadoEm!),
      criadoEm: dataHoraDaApi(criadoEm),
    );
  }
}
