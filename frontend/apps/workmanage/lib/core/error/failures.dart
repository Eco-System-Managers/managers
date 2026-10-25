import 'package:equatable/equatable.dart';

// toda falha carrega a mensagem que a tela pode mostrar (o detail que a API
// mandou) e, quando veio da API, o code: é por ele que a tela decide o
// fluxo, nunca pelo texto (backend/openapi/README.md)
abstract class Failure extends Equatable {
  const Failure({required this.message, this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

// 5xx, ou regra de negócio (400 com code próprio) que a tela trata pelo code
class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'Erro no servidor. Tente novamente.',
    super.code,
  });
}

// 400 com code invalido: além da mensagem, o que falhou em cada campo, para
// o formulário mostrar embaixo do campo certo
class ValidationFailure extends Failure {
  const ValidationFailure({
    super.message = 'Dados inválidos.',
    super.code = 'invalido',
    this.fields = const {},
  });

  final Map<String, List<String>> fields;

  // a primeira mensagem de um campo; null quando o campo passou
  String? erroDe(String campo) => fields[campo]?.firstOrNull;

  // para quando não há formulário para pendurar a mensagem no campo: a
  // primeira mensagem de campo diz mais que o "Dados inválidos." genérico
  String get resumo => fields.values.expand((m) => m).firstOrNull ?? message;

  @override
  List<Object?> get props => [message, code, fields];
}

// 401: sessão expirada ou credenciais recusadas
class AuthFailure extends Failure {
  const AuthFailure({
    super.message = 'Sua sessão expirou. Entre de novo.',
    super.code,
  });
}

// 402: assinatura bloqueada (assinatura_bloqueada)
class SubscriptionFailure extends Failure {
  const SubscriptionFailure({
    super.message = 'Assinatura inativa. Assine um plano para continuar.',
    super.code,
  });
}

// 403: só o proprietário pode
class PermissionFailure extends Failure {
  const PermissionFailure({
    super.message = 'Você não tem permissão para isso.',
    super.code,
  });
}

// 404
class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message = 'Não encontrado.', super.code});
}

// a requisição nem chegou na API: rede, timeout, URL errada
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Não foi possível conectar ao servidor.',
    super.code,
  });
}

// armazenamento local
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Erro ao acessar os dados locais.',
    super.code,
  });
}
