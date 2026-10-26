import 'package:equatable/equatable.dart';

// o ciclo do contrato. enviado, assinado e recusado o dono marca na ficha,
// pelo que aconteceu fora do app (PDF pelo WhatsApp, papel). assinado e
// recusado encerram
enum StatusContrato {
  pendente('Pendente'),
  enviado('Enviado'),
  assinado('Assinado'),
  recusado('Recusado');

  const StatusContrato(this.nome);

  final String nome;

  bool get finalizado => this == assinado || this == recusado;

  static StatusContrato daApi(String valor) =>
      values.asNameMap()[valor] ?? pendente;
}

// a instância gerada para um cliente: o texto já vem com as variáveis
// substituídas e não muda mais
class Contrato extends Equatable {
  const Contrato({
    required this.id,
    this.modeloId,
    required this.clienteId,
    required this.clienteNome,
    this.clienteEmail = '',
    required this.titulo,
    required this.corpo,
    required this.status,
    this.nomeAssinante = '',
    this.assinadoEm,
    required this.criadoEm,
  });

  final int id;

  // null quando o modelo foi apagado depois: o texto continua aqui
  final int? modeloId;
  final int clienteId;
  final String clienteNome;
  final String clienteEmail;
  final String titulo;
  final String corpo;
  final StatusContrato status;
  final String nomeAssinante;
  final DateTime? assinadoEm;
  final DateTime criadoEm;

  @override
  List<Object?> get props => [
    id,
    modeloId,
    clienteId,
    clienteNome,
    clienteEmail,
    titulo,
    corpo,
    status,
    nomeAssinante,
    assinadoEm,
    criadoEm,
  ];
}
