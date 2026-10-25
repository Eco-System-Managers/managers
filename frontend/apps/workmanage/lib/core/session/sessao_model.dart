import 'sessao.dart';

// o JSON do schema Sessao, que também é o formato guardado no aparelho.
// o refresh é obrigatório: sem ele o app não teria como renovar, então
// uma resposta sem ele é erro, não sessão
class SessaoModel {
  const SessaoModel({
    required this.access,
    required this.refresh,
    required this.schemaName,
    required this.empresa,
  });

  final String access;
  final String refresh;
  final String schemaName;
  final String empresa;

  factory SessaoModel.fromJson(Map<String, dynamic> json) {
    return SessaoModel(
      access: json['access'] as String,
      refresh: json['refresh'] as String,
      schemaName: json['schema_name'] as String,
      empresa: json['empresa'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access': access,
      'refresh': refresh,
      'schema_name': schemaName,
      'empresa': empresa,
    };
  }

  factory SessaoModel.fromEntity(Sessao sessao) {
    return SessaoModel(
      access: sessao.access,
      refresh: sessao.refresh,
      schemaName: sessao.schemaName,
      empresa: sessao.empresa,
    );
  }

  Sessao toEntity() {
    return Sessao(
      access: access,
      refresh: refresh,
      schemaName: schemaName,
      empresa: empresa,
    );
  }
}
