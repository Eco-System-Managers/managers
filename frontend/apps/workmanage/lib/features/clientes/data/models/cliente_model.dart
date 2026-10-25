import 'package:managers/core/utils/datas.dart';

import '../../domain/entities/cliente.dart';
import 'objeto_cliente_model.dart';

// o schema Cliente do contrato. datas vêm como "2026-10-19"; a foto é uma
// URL assinada ('' para cadastro manual); veículos e pets vêm aninhados e
// só de leitura (mudam pelas rotas próprias)
class ClienteModel {
  const ClienteModel({
    required this.id,
    required this.nome,
    required this.telefone,
    required this.email,
    required this.cpf,
    required this.dataNascimento,
    required this.cep,
    required this.endereco,
    required this.numeroEndereco,
    required this.observacao,
    required this.alergia,
    required this.origem,
    required this.foto,
    required this.criadoEm,
    this.veiculos = const [],
    this.pets = const [],
  });

  final int id;
  final String nome;
  final String telefone;
  final String email;
  final String cpf;
  final String? dataNascimento;
  final String cep;
  final String endereco;
  final String numeroEndereco;
  final String observacao;
  final String alergia;
  final String origem;
  final String foto;
  final String? criadoEm;
  final List<Map<String, dynamic>> veiculos;
  final List<Map<String, dynamic>> pets;

  factory ClienteModel.fromJson(Map<String, dynamic> json) {
    return ClienteModel(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
      telefone: json['telefone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      cpf: json['cpf'] as String? ?? '',
      dataNascimento: json['data_nascimento'] as String?,
      cep: json['cep'] as String? ?? '',
      endereco: json['endereco'] as String? ?? '',
      numeroEndereco: json['numero_endereco'] as String? ?? '',
      observacao: json['observacao'] as String? ?? '',
      alergia: json['alergia'] as String? ?? '',
      origem: json['origem'] as String? ?? 'manual',
      foto: json['foto'] as String? ?? '',
      criadoEm: json['criado_em'] as String?,
      veiculos: (json['veiculos'] as List? ?? const [])
          .cast<Map<String, dynamic>>(),
      pets: (json['pets'] as List? ?? const []).cast<Map<String, dynamic>>(),
    );
  }

  // id, origem, foto e criado_em não vão: são da API. para o cliente que
  // veio do app, a API ignora os campos espelhados que o painel mandar
  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'telefone': telefone,
      'email': email,
      'cpf': cpf,
      'data_nascimento': dataNascimento,
      'cep': cep,
      'endereco': endereco,
      'numero_endereco': numeroEndereco,
      'observacao': observacao,
      'alergia': alergia,
    };
  }

  factory ClienteModel.fromEntity(Cliente cliente) {
    return ClienteModel(
      id: cliente.id,
      nome: cliente.nome,
      telefone: cliente.telefone,
      email: cliente.email,
      cpf: cliente.cpf,
      dataNascimento: cliente.dataNascimento == null
          ? null
          : dataParaApi(cliente.dataNascimento!),
      cep: cliente.cep,
      endereco: cliente.endereco,
      numeroEndereco: cliente.numeroEndereco,
      observacao: cliente.observacao,
      alergia: cliente.alergia,
      origem: cliente.origem.name,
      foto: cliente.fotoUrl,
      criadoEm: cliente.criadoEm == null
          ? null
          : dataHoraParaApi(cliente.criadoEm!),
    );
  }

  Cliente toEntity() {
    return Cliente(
      id: id,
      nome: nome,
      telefone: telefone,
      email: email,
      cpf: cpf,
      dataNascimento: dataNascimento == null || dataNascimento!.isEmpty
          ? null
          : dataDaApi(dataNascimento!),
      cep: cep,
      endereco: endereco,
      numeroEndereco: numeroEndereco,
      observacao: observacao,
      alergia: alergia,
      origem: OrigemCliente.values.asNameMap()[origem] ?? OrigemCliente.manual,
      fotoUrl: foto,
      criadoEm: criadoEm == null || criadoEm!.isEmpty
          ? null
          : dataHoraDaApi(criadoEm!),
      veiculos: [for (final v in veiculos) VeiculoModel.fromJson(v).toEntity()],
      pets: [for (final p in pets) PetModel.fromJson(p).toEntity()],
    );
  }
}
