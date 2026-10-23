import 'nicho.dart';

enum TipoDocumento { cpf, cnpj }

// quem decide é o backend, a partir do nicho: a entidade só guarda o resultado
enum TipoAgenda { horario, kanban }

// os dados do negócio que o onboarding preenche. a config nasce vazia no
// backend: texto vazio é '' e o que ainda não foi escolhido é null
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
    this.tipoAgenda = TipoAgenda.horario,
    this.onboardingConcluido = false,
  });

  final String nome;
  final String telefone;
  final TipoDocumento? tipoDocumento;

  // só os dígitos; a máscara fica na tela
  final String documento;

  final String cep;
  final String endereco;

  // ainda não existe no backend (EmpresaConfig não tem o campo)
  final String numero;

  final String cidade;
  final String uf;
  final Nicho? nicho;
  final TipoAgenda tipoAgenda;
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
    TipoAgenda? tipoAgenda,
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
      tipoAgenda: tipoAgenda ?? this.tipoAgenda,
      onboardingConcluido: onboardingConcluido ?? this.onboardingConcluido,
    );
  }
}
