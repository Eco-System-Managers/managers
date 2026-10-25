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
  });

  final int id;
  final String nome;
  final String email;
  final bool aceito;
  final DateTime criadoEm;
  final DateTime expiraEm;

  @override
  List<Object?> get props => [id, nome, email, aceito, criadoEm, expiraEm];
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
