import 'package:equatable/equatable.dart';
import 'package:managers/features/empresa/domain/entities/empresa_config.dart'
    show TipoObjeto;

import 'porte.dart';

export 'package:managers/features/empresa/domain/entities/empresa_config.dart'
    show TipoObjeto;

export 'porte.dart';

// o veículo do cliente (lava-rápido). os campos de texto e o porte são
// obrigatórios na API; o porte só vem null em cadastro de antes dele
class Veiculo extends Equatable {
  const Veiculo({
    this.id = 0,
    required this.clienteId,
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.cor,
    this.porte,
  });

  // 0 enquanto não existe na API
  final int id;
  final int clienteId;
  final String placa;
  final String marca;
  final String modelo;
  final String cor;
  final Porte? porte;

  bool get ehNovo => id == 0;

  // "Fiat Uno"
  String get titulo => [marca, modelo].where((t) => t.isNotEmpty).join(' ');

  // "ABC1D23 · Prata · Carro"
  String get detalhe => [
    placa,
    cor,
    if (porte != null) porte!.nome,
  ].where((t) => t.isNotEmpty).join(' · ');

  @override
  List<Object?> get props => [id, clienteId, placa, marca, modelo, cor, porte];
}

// o pet do cliente (banho & tosa). nome e porte são obrigatórios na API; o
// porte só vem null em cadastro de antes dele
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
  final Porte? porte;
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

  // "ABC1D23 · Prata · Carro" / "Cachorro · Poodle · Pequeno"
  String get detalhe => veiculo?.detalhe ?? pet!.detalhe;

  // decide quais serviços servem; null em cadastro de antes do porte
  Porte? get porte => veiculo != null ? veiculo!.porte : pet!.porte;

  @override
  List<Object?> get props => [tipo, veiculo, pet];
}
