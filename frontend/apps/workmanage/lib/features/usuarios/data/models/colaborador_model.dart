import '../../domain/entities/colaborador.dart';

// o schema Colaborador do contrato: o user vem aninhado (first_name,
// last_name, email) e o papel vem como texto ou null
class ColaboradorModel {
  const ColaboradorModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.funcao,
    required this.papel,
    required this.ativo,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String funcao;
  final String? papel;
  final bool ativo;

  factory ColaboradorModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    return ColaboradorModel(
      id: json['id'] as int,
      firstName: user['first_name'] as String? ?? '',
      lastName: user['last_name'] as String? ?? '',
      email: user['email'] as String? ?? '',
      funcao: json['funcao'] as String? ?? '',
      papel: json['papel'] as String?,
      ativo: json['ativo'] as bool? ?? true,
    );
  }

  Colaborador toEntity() {
    final nome = '$firstName $lastName'.trim();
    return Colaborador(
      id: id,
      // sem nome cadastrado, o e-mail identifica a pessoa na tela
      nome: nome.isEmpty ? email : nome,
      email: email,
      funcao: funcao,
      papel: Papel.values.asNameMap()[papel],
      ativo: ativo,
    );
  }
}
