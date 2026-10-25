import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

// adapter de teste do Dio: responde o que o teste mandar e guarda cada
// requisição, para datasources e interceptors serem testados sem rede.
// a resposta passa pelo Dio de verdade (parse do JSON, DioException em 4xx)
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  final List<RequestOptions> requisicoes = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requisicoes.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

// uma resposta JSON com o status dado
ResponseBody respostaJson(int status, Object? body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

// o corpo de erro da API: {detail, code, fields?}
ResponseBody respostaErro(
  int status,
  String code, {
  String detail = 'Erro.',
  Map<String, List<String>>? fields,
}) {
  return respostaJson(status, {
    'detail': detail,
    'code': code,
    'fields': ?fields,
  });
}

// um Dio apontado para o adapter, com a base URL e os cabeçalhos do app
Dio dioDeTeste(FakeAdapter adapter) {
  return Dio(
    BaseOptions(
      baseUrl: 'http://api.teste/api/v1/',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Client-Platform': 'mobile',
      },
    ),
  )..httpClientAdapter = adapter;
}
