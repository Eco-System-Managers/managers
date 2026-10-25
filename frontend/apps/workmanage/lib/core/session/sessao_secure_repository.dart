import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sessao.dart';
import 'sessao_model.dart';
import 'sessao_repository.dart';

// guarda a sessão no armazenamento seguro do aparelho (Keychain no iOS,
// Keystore no Android), como um JSON só: os tokens andam sempre juntos
class SessaoSecureRepository implements SessaoRepository {
  SessaoSecureRepository([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _chave = 'sessao';

  @override
  Future<Sessao?> carregar() async {
    final texto = await _storage.read(key: _chave);
    if (texto == null) return null;
    try {
      final json = jsonDecode(texto) as Map<String, dynamic>;
      return SessaoModel.fromJson(json).toEntity();
    } catch (_) {
      // guardado corrompido (versão antiga do formato, por exemplo): vale
      // mais pedir login de novo do que travar a abertura do app
      await _storage.delete(key: _chave);
      return null;
    }
  }

  @override
  Future<void> salvar(Sessao sessao) {
    final json = SessaoModel.fromEntity(sessao).toJson();
    return _storage.write(key: _chave, value: jsonEncode(json));
  }

  @override
  Future<void> limpar() => _storage.delete(key: _chave);
}
