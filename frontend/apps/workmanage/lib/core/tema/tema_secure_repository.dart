import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'preferencia_de_tema.dart';
import 'tema_repository.dart';

// guarda o tema no mesmo armazenamento do aparelho que a sessão usa: o app
// já depende dele, e a escolha é uma palavra só
class TemaSecureRepository implements TemaRepository {
  TemaSecureRepository([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _chave = 'tema';

  @override
  Future<PreferenciaDeTema> carregar() async {
    try {
      final nome = await _storage.read(key: _chave);
      return PreferenciaDeTema.values.asNameMap()[nome] ??
          PreferenciaDeTema.sistema;
    } catch (_) {
      // o armazenamento falhou: o tema do aparelho, em vez de travar a
      // abertura do app por causa de uma preferência visual
      return PreferenciaDeTema.sistema;
    }
  }

  @override
  Future<void> salvar(PreferenciaDeTema preferencia) =>
      _storage.write(key: _chave, value: preferencia.name);
}
