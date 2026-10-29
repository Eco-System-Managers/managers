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
    required this.nichos,
    required this.nichoDescricao,
    required this.tipoAgenda,
    required this.tipoObjeto,
    required this.logoUrl,
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
  final List<String> nichos;
  final String nichoDescricao;
  final String tipoAgenda;
  final String tipoObjeto;
  final String logoUrl;
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
      numero: json['numero'] as String? ?? '',
      cidade: json['cidade'] as String? ?? '',
      uf: json['uf'] as String? ?? '',
      nichos: (json['nichos'] as List? ?? const []).cast<String>(),
      nichoDescricao: json['nicho_descricao'] as String? ?? '',
      tipoAgenda: json['tipo_agenda'] as String? ?? 'horario',
      tipoObjeto: json['tipo_objeto'] as String? ?? '',
      logoUrl: json['logo_url'] as String? ?? '',
      onboardingConcluido: json['onboarding_concluido'] as bool? ?? false,
    );
  }

  // onboarding_concluido não vai: tem chamada própria (concluir). logo_url
  // não vai: muda pelo upload. tipo_agenda e tipo_objeto vão sempre, mas o
  // backend só usa no nicho outro; nos demais ele deduz os dois dos nichos
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
      // antes do passo dos nichos não há o que mandar; lista vazia a API
      // recusa depois que o negócio já escolheu
      if (nichos.isNotEmpty) 'nichos': nichos,
      'nicho_descricao': nichoDescricao,
      'tipo_agenda': tipoAgenda,
      'tipo_objeto': tipoObjeto,
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
      nichos: [for (final n in config.nichos) n.slug],
      nichoDescricao: config.nichoDescricao,
      tipoAgenda: config.tipoAgenda.name,
      tipoObjeto: config.tipoObjeto?.name ?? '',
      logoUrl: config.logoUrl,
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
      // slug desconhecido fica de fora; sem nenhum, o wizard pede para
      // escolher de novo
      nichos: [for (final slug in nichos) ?Nicho.doSlug(slug)],
      nichoDescricao: nichoDescricao,
      tipoAgenda:
          TipoAgenda.values.asNameMap()[tipoAgenda] ?? TipoAgenda.horario,
      tipoObjeto: TipoObjeto.values.asNameMap()[tipoObjeto],
      logoUrl: logoUrl,
      onboardingConcluido: onboardingConcluido,
    );
  }
}
