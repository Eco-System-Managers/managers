import 'package:equatable/equatable.dart';

import 'objeto_cliente.dart';

// de onde veio o cadastro. quem nasceu no app do cliente (Service Manage)
// mantém a própria ficha por lá: o painel só edita o que é do negócio
enum OrigemCliente { manual, servicemanage }

// a ficha do cliente dentro do negócio
class Cliente extends Equatable {
  const Cliente({
    this.id = 0,
    required this.nome,
    required this.telefone,
    this.email = '',
    this.cpf = '',
    this.dataNascimento,
    this.cep = '',
    this.endereco = '',
    this.numeroEndereco = '',
    this.observacao = '',
    this.alergia = '',
    this.origem = OrigemCliente.manual,
    this.fotoUrl = '',
    this.criadoEm,
    this.veiculos = const [],
    this.pets = const [],
  });

  // 0 enquanto não existe na API
  final int id;
  final String nome;

  // só os dígitos; a máscara fica na tela. obrigatório: é por ele que o
  // negócio fala com o cliente
  final String telefone;
  final String email;

  // só os dígitos
  final String cpf;
  final DateTime? dataNascimento;
  final String cep;
  final String endereco;
  final String numeroEndereco;
  final String observacao;

  // campo dos nichos de beleza
  final String alergia;
  final OrigemCliente origem;

  // URL assinada da foto, só para quem veio do app; '' para cadastro manual
  final String fotoUrl;
  final DateTime? criadoEm;

  // os objetos do cliente, aninhados no cadastro (só os negócios por
  // esteira usam: lava-rápido tem veículos, banho & tosa tem pets)
  final List<Veiculo> veiculos;
  final List<Pet> pets;

  bool get ehNovo => id == 0;

  List<ObjetoCliente> objetosDoTipo(TipoObjeto tipo) => switch (tipo) {
    TipoObjeto.veiculo => [for (final v in veiculos) ObjetoCliente.veiculo(v)],
    TipoObjeto.pet => [for (final p in pets) ObjetoCliente.pet(p)],
  };

  // o cadastro é mantido pela pessoa no app: nome, telefone, CPF, nascimento
  // e endereço só mudam por lá (a API ignora o que o painel mandar neles)
  bool get veioDoApp => origem == OrigemCliente.servicemanage;

  Cliente copyWith({
    int? id,
    String? nome,
    String? telefone,
    String? email,
    String? cpf,
    DateTime? dataNascimento,
    bool semNascimento = false,
    String? cep,
    String? endereco,
    String? numeroEndereco,
    String? observacao,
    String? alergia,
    OrigemCliente? origem,
    String? fotoUrl,
    DateTime? criadoEm,
    List<Veiculo>? veiculos,
    List<Pet>? pets,
  }) {
    return Cliente(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      telefone: telefone ?? this.telefone,
      email: email ?? this.email,
      cpf: cpf ?? this.cpf,
      // semNascimento limpa a data; sem ele, null significa "não mexer"
      dataNascimento: semNascimento
          ? null
          : dataNascimento ?? this.dataNascimento,
      cep: cep ?? this.cep,
      endereco: endereco ?? this.endereco,
      numeroEndereco: numeroEndereco ?? this.numeroEndereco,
      observacao: observacao ?? this.observacao,
      alergia: alergia ?? this.alergia,
      origem: origem ?? this.origem,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      criadoEm: criadoEm ?? this.criadoEm,
      veiculos: veiculos ?? this.veiculos,
      pets: pets ?? this.pets,
    );
  }

  @override
  List<Object?> get props => [
    id,
    nome,
    telefone,
    email,
    cpf,
    dataNascimento,
    cep,
    endereco,
    numeroEndereco,
    observacao,
    alergia,
    origem,
    fotoUrl,
    criadoEm,
    veiculos,
    pets,
  ];
}
