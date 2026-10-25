import 'nicho.dart';

enum TipoDocumento { cpf, cnpj }

// nos nichos da lista, quem decide é o backend; no outro, é o dono
enum TipoAgenda { horario, kanban }

// o que o cliente deixa no negócio, no kanban. no horário não há objeto
enum TipoObjeto { veiculo, pet }

// os dados do negócio. a config nasce no backend só com o nome do cadastro:
// texto vazio é '' e o que ainda não foi escolhido é null
class EmpresaConfig {
  const EmpresaConfig({
    this.nome = '',
    this.telefone = '',
    this.tipoDocumento,
    this.documento = '',
    this.cep = '',
    this.endereco = '',
    this.numero = '',
    this.cidade = '',
    this.uf = '',
    this.nicho,
    this.nichoDescricao = '',
    this.tipoAgenda = TipoAgenda.horario,
    this.tipoObjeto,
    this.logoUrl = '',
    this.onboardingConcluido = false,
  });

  final String nome;
  final String telefone;
  final TipoDocumento? tipoDocumento;

  // só os dígitos; a máscara fica na tela
  final String documento;

  final String cep;
  final String endereco;
  final String numero;
  final String cidade;
  final String uf;
  final Nicho? nicho;

  // o ramo por extenso, só quando o nicho é outro
  final String nichoDescricao;

  final TipoAgenda tipoAgenda;
  final TipoObjeto? tipoObjeto;

  // URL pública no S3; '' enquanto não houver logo. muda pelo upload, não
  // pelo formulário
  final String logoUrl;

  final bool onboardingConcluido;

  // o wizard vai preenchendo aos poucos: cada etapa troca só os seus campos
  EmpresaConfig copyWith({
    String? nome,
    String? telefone,
    TipoDocumento? tipoDocumento,
    String? documento,
    String? cep,
    String? endereco,
    String? numero,
    String? cidade,
    String? uf,
    Nicho? nicho,
    String? nichoDescricao,
    TipoAgenda? tipoAgenda,
    TipoObjeto? tipoObjeto,
    String? logoUrl,
    bool? onboardingConcluido,
  }) {
    return EmpresaConfig(
      nome: nome ?? this.nome,
      telefone: telefone ?? this.telefone,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      documento: documento ?? this.documento,
      cep: cep ?? this.cep,
      endereco: endereco ?? this.endereco,
      numero: numero ?? this.numero,
      cidade: cidade ?? this.cidade,
      uf: uf ?? this.uf,
      nicho: nicho ?? this.nicho,
      nichoDescricao: nichoDescricao ?? this.nichoDescricao,
      tipoAgenda: tipoAgenda ?? this.tipoAgenda,
      tipoObjeto: tipoObjeto ?? this.tipoObjeto,
      logoUrl: logoUrl ?? this.logoUrl,
      onboardingConcluido: onboardingConcluido ?? this.onboardingConcluido,
    );
  }
}
