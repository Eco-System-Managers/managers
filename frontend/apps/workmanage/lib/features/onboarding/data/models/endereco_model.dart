import '../../domain/entities/endereco.dart';

// o formato da busca por CEP. as chaves seguem o nosso padrão; quando a
// busca real existir (Google ou outra API), é só aqui que o JSON muda
class EnderecoModel {
  const EnderecoModel({
    required this.cep,
    required this.endereco,
    required this.cidade,
    required this.uf,
  });

  final String cep;
  final String endereco;
  final String cidade;
  final String uf;

  factory EnderecoModel.fromJson(Map<String, dynamic> json) {
    return EnderecoModel(
      cep: json['cep'] as String? ?? '',
      endereco: json['endereco'] as String? ?? '',
      cidade: json['cidade'] as String? ?? '',
      uf: json['uf'] as String? ?? '',
    );
  }

  Endereco toEntity() {
    return Endereco(cep: cep, endereco: endereco, cidade: cidade, uf: uf);
  }
}
