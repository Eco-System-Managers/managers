import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// um único Dio para o app inteiro: as features pegam daqui via ref
final dioProvider = Provider<Dio>((ref) => DioClient.create());

class DioClient {
  static Dio create() {
    return Dio(
      BaseOptions(
        baseUrl: 'http://127.0.0.1:8000/api/v1/',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }
}
