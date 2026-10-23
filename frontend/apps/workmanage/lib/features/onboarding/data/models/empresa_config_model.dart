import '../../domain/entities/empresa_config.dart';
import '../../domain/entities/nicho.dart';

// o formato do /empresa/config/ do backend. conhece o JSON e converte de e
// para a entidade, que não sabe nada de API
class EmpresaConfigModel {
  const EmpresaConfigModel({
    required this.nome,
    required this.telefone,
    required this.tipoDocumento,
    required this.documento,
    required this.cep,
    required this.endereco,
    required this.numero,
    required this.cidade,
    required this.uf,
    required this.nicho,
    required this.tipoAgenda,
    required this.onboardingConcluido,
  });

  final String nome;
  final String telefone;
  final String tipoDocumento;
  final String documento;
  final String cep;
  final String endereco;
  final String numero;
  final String cidade;
  final String uf;
  final String nicho;
  final String tipoAgenda;
  final bool onboardingConcluido;

  // o backend manda '' no que está vazio; o ?? cobre campo ausente
  factory EmpresaConfigModel.fromJson(Map<String, dynamic> json) {
    return EmpresaConfigModel(
      nome: json['nome'] as String? ?? '',
      telefone: json['telefone'] as String? ?? '',
      tipoDocumento: json['tipo_documento'] as String? ?? '',
      documento: json['documento'] as String? ?? '',
      cep: json['cep'] as String? ?? '',
      endereco: json['endereco'] as String? ?? '',
      // ainda não existe no backend: vem sempre vazio por enquanto
      numero: json['numero'] as String? ?? '',
      cidade: json['cidade'] as String? ?? '',
      uf: json['uf'] as String? ?? '',
      nicho: json['nicho'] as String? ?? '',
      tipoAgenda: json['tipo_agenda'] as String? ?? 'horario',
      onboardingConcluido: json['onboarding_concluido'] as bool? ?? false,
    );
  }

  // tipo_agenda e onboarding_concluido não vão: o primeiro é só leitura e o
  // segundo tem endpoint próprio (concluir)
  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'telefone': telefone,
      'tipo_documento': tipoDocumento,
      'documento': documento,
      'cep': cep,
      'endereco': endereco,
      'numero': numero,
      'cidade': cidade,
      'uf': uf,
      'nicho': nicho,
    };
  }

  factory EmpresaConfigModel.fromEntity(EmpresaConfig config) {
    return EmpresaConfigModel(
      nome: config.nome,
      telefone: config.telefone,
      tipoDocumento: config.tipoDocumento?.name ?? '',
      documento: config.documento,
      cep: config.cep,
      endereco: config.endereco,
      numero: config.numero,
      cidade: config.cidade,
      uf: config.uf,
      nicho: config.nicho?.slug ?? '',
      tipoAgenda: config.tipoAgenda.name,
      onboardingConcluido: config.onboardingConcluido,
    );
  }

  EmpresaConfig toEntity() {
    return EmpresaConfig(
      nome: nome,
      telefone: telefone,
      tipoDocumento: TipoDocumento.values.asNameMap()[tipoDocumento],
      documento: documento,
      cep: cep,
      endereco: endereco,
      numero: numero,
      cidade: cidade,
      uf: uf,
      // slug desconhecido vira null: o wizard pede para escolher de novo
      nicho: Nicho.values.where((n) => n.slug == nicho).firstOrNull,
      tipoAgenda:
          TipoAgenda.values.asNameMap()[tipoAgenda] ?? TipoAgenda.horario,
      onboardingConcluido: onboardingConcluido,
    );
  }
}
