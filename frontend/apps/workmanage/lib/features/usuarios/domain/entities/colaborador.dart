import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

// o papel vem do Membro, no schema público: é ele que libera a escrita em
// serviços, configurações, equipe e assinatura
enum Papel { proprietario, colaborador }

// o vínculo decide o que a pessoa vê. parceiro: agenda e faturamento
// próprios (comissão), vê os próprios números. colaborador: executa e não vê
// valores. a API trava dos dois lados; a tela só esconde
enum VinculoColaborador {
  parceiro('Parceiro'),
  colaborador('Colaborador');

  const VinculoColaborador(this.nome);

  final String nome;

  static VinculoColaborador daApi(String? valor) =>
      values.asNameMap()[valor] ?? parceiro;
}

// quem trabalha no negócio. o login é opcional: o dono cadastra a pessoa na
// hora e, se quiser dar acesso, convida depois (o mesmo registro ganha o
// login)
class Colaborador extends Equatable {
  const Colaborador({
    required this.id,
    required this.nome,
    this.email = '',
    this.temAcesso = false,
    this.funcao = '',
    this.tipo = VinculoColaborador.parceiro,
    this.comissaoPercentual,
    this.podeCobrar = true,
    this.papel,
    this.ativo = true,
  });

  final int id;
  final String nome;

  // vazio para quem não tem login
  final String email;
  final bool temAcesso;

  // cargo exibido (ex.: "Cabeleireiro")
  final String funcao;
  final VinculoColaborador tipo;

  // só para parceiro: a parte dele sobre cada pagamento (0 a 100); null é
  // sem acordo registrado. congela em cada pagamento na cobrança
  final Decimal? comissaoPercentual;

  // só pesa para o colaborador comum: parceiro e dono cobram sempre
  final bool podeCobrar;

  // null para quem não tem login (não há Membro)
  final Papel? papel;

  final bool ativo;

  bool get ehProprietario => papel == Papel.proprietario;
  bool get ehParceiro => tipo == VinculoColaborador.parceiro;

  // dono e parceiro veem dinheiro; o colaborador comum não
  bool get veValores => ehProprietario || ehParceiro;

  // dono e parceiro cobram sempre; o colaborador comum só com a flag
  bool get cobra => ehProprietario || ehParceiro || podeCobrar;

  @override
  List<Object?> get props => [
    id,
    nome,
    email,
    temAcesso,
    funcao,
    tipo,
    comissaoPercentual,
    podeCobrar,
    papel,
    ativo,
  ];
}
