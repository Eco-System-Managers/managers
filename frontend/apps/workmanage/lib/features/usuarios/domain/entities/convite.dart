import 'package:equatable/equatable.dart';

// um convite pendente da equipe: a API só lista os que ainda não foram
// aceitos e não expiraram (2 dias)
class Convite extends Equatable {
  const Convite({
    required this.id,
    required this.nome,
    required this.email,
    required this.aceito,
    required this.criadoEm,
    required this.expiraEm,
    this.colaboradorId,
    this.link = '',
  });

  final int id;
  final String nome;
  final String email;
  final bool aceito;
  final DateTime criadoEm;
  final DateTime expiraEm;

  // quem da equipe ganha o login ao aceitar; null nos convites antigos,
  // feitos sem a pessoa cadastrada
  final int? colaboradorId;

  // o mesmo link do e-mail, para mandar por WhatsApp
  final String link;

  @override
  List<Object?> get props => [
    id,
    nome,
    email,
    aceito,
    criadoEm,
    expiraEm,
    colaboradorId,
    link,
  ];
}

// o que o convidado vê antes de aceitar (rota pública, pelo token)
class ConviteInfo extends Equatable {
  const ConviteInfo({
    required this.nome,
    required this.email,
    required this.expiraEm,
  });

  final String nome;
  final String email;
  final DateTime expiraEm;

  @override
  List<Object?> get props => [nome, email, expiraEm];
}
