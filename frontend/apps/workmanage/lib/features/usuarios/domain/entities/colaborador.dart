import 'package:equatable/equatable.dart';

// o papel vem do Membro, no schema público: é ele que libera a escrita em
// serviços, configurações, equipe e assinatura
enum Papel { proprietario, colaborador }

// quem trabalha no negócio. o login é do User do Django; isto é o lado do
// domínio, com o cargo exibido e o papel
class Colaborador extends Equatable {
  const Colaborador({
    required this.id,
    required this.nome,
    required this.email,
    this.funcao = '',
    this.papel,
    this.ativo = true,
  });

  final int id;
  final String nome;
  final String email;

  // cargo exibido (ex.: "Cabeleireiro")
  final String funcao;

  // null quando a API não devolveu (não deveria acontecer num tenant)
  final Papel? papel;

  final bool ativo;

  bool get ehProprietario => papel == Papel.proprietario;

  @override
  List<Object?> get props => [id, nome, email, funcao, papel, ativo];
}
