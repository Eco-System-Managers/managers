import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/repositories/novidades_repository.dart';

// guarda no mesmo armazenamento do aparelho que a sessão e o tema usam: é
// uma palavra só (a versão), e o logout não a apaga
class NovidadesRepositoryImpl implements NovidadesRepository {
  NovidadesRepositoryImpl([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _chave = 'novidades_vistas';

  @override
  Future<String?> ultimaVista() => _storage.read(key: _chave);

  @override
  Future<void> marcarVista(String versao) =>
      _storage.write(key: _chave, value: versao);
}
