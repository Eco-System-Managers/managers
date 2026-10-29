import 'package:dio/dio.dart';

import 'api_erro.dart';
import 'failures.dart';

// traduz o erro do Dio no Failure que a tela entende. o status escolhe o
// tipo; a mensagem é sempre o detail que a API mandou, e o code vai junto.
// todo repository usa isto no catch, para a tradução existir num lugar só
Failure failureFrom(DioException e) {
  final response = e.response;

  // sem resposta a requisição nem chegou na API: rede, timeout, URL errada
  if (response == null) return const NetworkFailure();

  final erro = ApiErro.fromJson(response.data);
  final status = response.statusCode ?? 0;
  final message =
      erro?.detail ?? 'Erro no servidor ($status). Tente novamente.';
  final code = erro?.code;
  final fields = erro?.fields ?? const <String, List<String>>{};

  return switch (status) {
    400 when code == 'invalido' || fields.isNotEmpty => ValidationFailure(
      message: message,
      code: code,
      fields: fields,
    ),
    401 => AuthFailure(message: message, code: code),
    402 => SubscriptionFailure(code: code),
    403 => PermissionFailure(message: message, code: code),
    404 => NotFoundFailure(message: message, code: code),
    _ => ServerFailure(message: message, code: code),
  };
}
