import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../session/sessao_controller.dart';
import '../session/sessao_provider.dart';
import 'auth_interceptor.dart';

// um único Dio para o app inteiro: as features pegam daqui via ref
final dioProvider = Provider<Dio>(
  (ref) => DioClient.create(ref.watch(sessaoControllerProvider)),
);

class DioClient {
  static Dio create(SessaoController sessao) {
    final dio = Dio(_opcoes());
    dio.interceptors.add(
      AuthInterceptor(sessao: sessao, dio: dio, dioRenovacao: Dio(_opcoes())),
    );
    return dio;
  }

  // o app se identifica como mobile em toda requisição: é o que faz o
  // refresh vir e ir no corpo, em vez do cookie (backend/core/sessao.py)
  static BaseOptions _opcoes() {
    return BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Client-Platform': 'mobile',
      },
    );
  }
}
