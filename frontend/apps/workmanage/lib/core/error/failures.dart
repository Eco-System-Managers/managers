import 'package:equatable/equatable.dart';

// toda falha carrega a mensagem que a tela pode mostrar ao usuário
abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object> get props => [message];
}

// General failures
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Erro no servidor. Tente novamente.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Erro ao acessar os dados locais.']);
}
