import 'package:equatable/equatable.dart';

// a sessão do app: o que login, cadastro confirmado e renovação devolvem
// (schema Sessao do contrato). o refresh vem no corpo porque o app manda
// X-Client-Platform: mobile em toda requisição
class Sessao extends Equatable {
  const Sessao({
    required this.access,
    required this.refresh,
    required this.schemaName,
    required this.empresa,
  });

  final String access;

  // cada refresh vale uma vez: a renovação devolve outro e revoga este
  final String refresh;

  // o tenant. já vai dentro do token; fica aqui para montar links públicos
  final String schemaName;

  // nome do negócio, para a tela não depender da config para mostrá-lo
  final String empresa;

  @override
  List<Object> get props => [access, refresh, schemaName, empresa];
}
