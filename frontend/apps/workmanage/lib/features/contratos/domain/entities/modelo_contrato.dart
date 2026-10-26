import 'package:equatable/equatable.dart';

// o texto reaproveitável: ao gerar, a API troca as variáveis pelos dados do
// cliente e congela o resultado no contrato
class ModeloContrato extends Equatable {
  const ModeloContrato({
    this.id = 0,
    required this.titulo,
    required this.corpo,
    this.ativo = true,
    this.criadoEm,
  });

  // as variáveis que a API substitui, na ordem em que a tela as oferece
  static const variaveis = [
    ('cliente_nome', 'Nome do cliente'),
    ('cliente_email', 'E-mail do cliente'),
    ('cliente_cpf', 'CPF do cliente'),
    ('data', 'Data de hoje'),
    ('negocio_nome', 'Nome do negócio'),
  ];

  // 0 enquanto não existe na API
  final int id;
  final String titulo;
  final String corpo;
  final bool ativo;
  final DateTime? criadoEm;

  bool get ehNovo => id == 0;

  ModeloContrato copyWith({
    int? id,
    String? titulo,
    String? corpo,
    bool? ativo,
    DateTime? criadoEm,
  }) {
    return ModeloContrato(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      corpo: corpo ?? this.corpo,
      ativo: ativo ?? this.ativo,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }

  @override
  List<Object?> get props => [id, titulo, corpo, ativo, criadoEm];
}
