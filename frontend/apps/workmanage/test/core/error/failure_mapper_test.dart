import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failure_mapper.dart';
import 'package:managers/core/error/failures.dart';

DioException _erro(int? status, Object? data) {
  final options = RequestOptions(path: 'x/');
  return DioException(
    requestOptions: options,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status, data: data),
    type: status == null
        ? DioExceptionType.connectionError
        : DioExceptionType.badResponse,
  );
}

void main() {
  group('failureFrom', () {
    test('sem resposta vira NetworkFailure', () {
      expect(failureFrom(_erro(null, null)), isA<NetworkFailure>());
    });

    test('400 com code invalido vira ValidationFailure com os campos', () {
      final failure = failureFrom(
        _erro(400, {
          'detail': 'Dados inválidos.',
          'code': 'invalido',
          'fields': {
            'email': ['Informe um endereço de email válido.'],
          },
        }),
      );
      expect(failure, isA<ValidationFailure>());
      final validacao = failure as ValidationFailure;
      expect(validacao.erroDe('email'), 'Informe um endereço de email válido.');
      expect(validacao.erroDe('nome'), isNull);
      expect(validacao.resumo, 'Informe um endereço de email válido.');
    });

    test('400 de regra de negócio mantém o code para a tela decidir', () {
      final failure = failureFrom(
        _erro(400, {
          'detail': 'O modo de agenda não pode ser trocado.',
          'code': 'modo_agenda_bloqueado',
        }),
      );
      expect(failure, isA<ServerFailure>());
      expect(failure.code, 'modo_agenda_bloqueado');
      expect(failure.message, 'O modo de agenda não pode ser trocado.');
    });

    test('401, 402, 403 e 404 viram os Failures de cada status', () {
      expect(
        failureFrom(_erro(401, {'detail': 'x', 'code': 'token_invalido'})),
        isA<AuthFailure>(),
      );
      expect(
        failureFrom(
          _erro(402, {'detail': 'x', 'code': 'assinatura_bloqueada'}),
        ),
        isA<SubscriptionFailure>(),
      );
      expect(
        failureFrom(_erro(403, {'detail': 'x', 'code': 'sem_permissao'})),
        isA<PermissionFailure>(),
      );
      expect(
        failureFrom(_erro(404, {'detail': 'x', 'code': 'nao_encontrado'})),
        isA<NotFoundFailure>(),
      );
    });

    test('a mensagem é o detail da API, e o code vai junto', () {
      final failure = failureFrom(
        _erro(401, {
          'detail': 'E-mail ou senha inválidos.',
          'code': 'credenciais_invalidas',
        }),
      );
      expect(failure.message, 'E-mail ou senha inválidos.');
      expect(failure.code, 'credenciais_invalidas');
    });

    test('resposta fora do contrato vira ServerFailure genérico', () {
      final failure = failureFrom(_erro(502, '<html>Bad Gateway</html>'));
      expect(failure, isA<ServerFailure>());
      expect(failure.code, isNull);
      expect(failure.message, contains('502'));
    });
  });
}
