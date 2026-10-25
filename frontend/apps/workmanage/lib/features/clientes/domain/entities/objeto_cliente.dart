import 'package:equatable/equatable.dart';
import 'package:managers/features/empresa/domain/entities/empresa_config.dart'
    show TipoObjeto;

export 'package:managers/features/empresa/domain/entities/empresa_config.dart'
    show TipoObjeto;

// o porte do pet, como a API guarda
enum PortePet { pequeno, medio, grande, gigante }

extension PortePetNomes on PortePet {
  String get nome => switch (this) {
    PortePet.pequeno => 'Pequeno',
    PortePet.medio => 'Médio',
    PortePet.grande => 'Grande',
    PortePet.gigante => 'Gigante',
  };
}

// o veículo do cliente (lava-rápido). os quatro campos são obrigatórios na API
class Veiculo extends Equatable {
  const Veiculo({
    this.id = 0,
    required this.clienteId,
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.cor,
  });

  // 0 enquanto não existe na API
  final int id;
  final int clienteId;
  final String placa;
  final String marca;
  final String modelo;
  final String cor;

  bool get ehNovo => id == 0;

  // "Fiat Uno"
  String get titulo => [marca, modelo].where((t) => t.isNotEmpty).join(' ');

  // "ABC1D23 · Prata"
  String get detalhe => [placa, cor].where((t) => t.isNotEmpty).join(' · ');

  @override
  List<Object?> get props => [id, clienteId, placa, marca, modelo, cor];
}

// o pet do cliente (banho & tosa). só o nome é obrigatório
class Pet extends Equatable {
  const Pet({
    this.id = 0,
    required this.clienteId,
    required this.nome,
    this.especie = '',
    this.raca = '',
    this.porte,
    this.dataNascimento,
  });

  final int id;
  final int clienteId;
  final String nome;
  final String especie;
  final String raca;
  final PortePet? porte;
  final DateTime? dataNascimento;

  bool get ehNovo => id == 0;

  // "Cachorro · Poodle · Pequeno"
  String get detalhe => [
    especie,
    raca,
    if (porte != null) porte!.nome,
  ].where((t) => t.isNotEmpty).join(' · ');

  @override
  List<Object?> get props => [
    id,
    clienteId,
    nome,
    especie,
    raca,
    porte,
    dataNascimento,
  ];
}

// o que entra na esteira: um veículo ou um pet. o id é o do ObjetoCliente
// da API (o mesmo do veículo ou do pet, por herança)
class ObjetoCliente extends Equatable {
  const ObjetoCliente.veiculo(Veiculo this.veiculo)
    : pet = null,
      tipo = TipoObjeto.veiculo;

  const ObjetoCliente.pet(Pet this.pet) : veiculo = null, tipo = TipoObjeto.pet;

  final TipoObjeto tipo;
  final Veiculo? veiculo;
  final Pet? pet;

  int get id => veiculo?.id ?? pet!.id;
  int get clienteId => veiculo?.clienteId ?? pet!.clienteId;

  // "Fiat Uno" / "Rex"
  String get titulo => veiculo?.titulo ?? pet!.nome;

  // "ABC1D23 · Prata" / "Cachorro · Poodle"
  String get detalhe => veiculo?.detalhe ?? pet!.detalhe;

  @override
  List<Object?> get props => [tipo, veiculo, pet];
}
