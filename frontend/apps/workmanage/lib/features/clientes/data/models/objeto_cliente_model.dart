import 'package:managers/core/utils/datas.dart';

import '../../domain/entities/objeto_cliente.dart';

// os schemas Veiculo, Pet e ObjetoCliente do contrato

class VeiculoModel {
  const VeiculoModel(this.json);

  final Map<String, dynamic> json;

  factory VeiculoModel.fromJson(Map<String, dynamic> json) =>
      VeiculoModel(json);

  Veiculo toEntity() {
    return Veiculo(
      id: json['id'] as int,
      clienteId: json['cliente'] as int,
      placa: json['placa'] as String? ?? '',
      marca: json['marca'] as String? ?? '',
      modelo: json['modelo'] as String? ?? '',
      cor: json['cor'] as String? ?? '',
      // vem vazio em cadastro de antes do porte
      porte: Porte.daApi(json['porte'] as String?),
    );
  }

  // o corpo de criação e edição (VeiculoRequest). a API exige o porte; o
  // formulário só salva com ele escolhido
  static Map<String, dynamic> toJson(Veiculo veiculo) => {
    'cliente': veiculo.clienteId,
    'placa': veiculo.placa,
    'marca': veiculo.marca,
    'modelo': veiculo.modelo,
    'cor': veiculo.cor,
    'porte': veiculo.porte?.name ?? '',
  };
}

class PetModel {
  const PetModel(this.json);

  final Map<String, dynamic> json;

  factory PetModel.fromJson(Map<String, dynamic> json) => PetModel(json);

  Pet toEntity() {
    final nascimento = json['data_nascimento'] as String?;
    return Pet(
      id: json['id'] as int,
      clienteId: json['cliente'] as int,
      nome: json['nome'] as String? ?? '',
      especie: json['especie'] as String? ?? '',
      raca: json['raca'] as String? ?? '',
      // vem vazio em cadastro de antes do porte obrigatório
      porte: Porte.daApi(json['porte'] as String?),
      dataNascimento: nascimento == null ? null : dataDaApi(nascimento),
    );
  }

  // o corpo de criação e edição (PetRequest)
  static Map<String, dynamic> toJson(Pet pet) => {
    'cliente': pet.clienteId,
    'nome': pet.nome,
    'especie': pet.especie,
    'raca': pet.raca,
    'porte': pet.porte?.name ?? '',
    'data_nascimento': pet.dataNascimento == null
        ? null
        : dataParaApi(pet.dataNascimento!),
  };
}

// o schema ObjetoCliente ({id, tipo, criado_em, detalhe}), como vem em
// objeto_detalhe do atendimento do kanban
ObjetoCliente objetoDoJson(Map<String, dynamic> json) {
  final detalhe = json['detalhe'] as Map<String, dynamic>;
  if (json['tipo'] == 'pet') {
    return ObjetoCliente.pet(PetModel.fromJson(detalhe).toEntity());
  }
  return ObjetoCliente.veiculo(VeiculoModel.fromJson(detalhe).toEntity());
}
