import 'package:flutter/foundation.dart';

import 'preferencia_de_tema.dart';
import 'tema_repository.dart';

// o tema escolhido, em memória, para o app inteiro: o MaterialApp escuta
// daqui. carrega antes do primeiro quadro (main.dart), para o app não abrir
// no tema do aparelho e trocar em seguida
class TemaController extends ChangeNotifier {
  TemaController(this._repository);

  final TemaRepository _repository;

  PreferenciaDeTema _preferencia = PreferenciaDeTema.sistema;

  PreferenciaDeTema get preferencia => _preferencia;

  Future<void> carregar() async {
    _preferencia = await _repository.carregar();
    notifyListeners();
  }

  // a tela troca na hora; guardar é para a próxima abertura
  Future<void> escolher(PreferenciaDeTema preferencia) async {
    if (preferencia == _preferencia) return;
    _preferencia = preferencia;
    notifyListeners();
    try {
      await _repository.salvar(preferencia);
    } catch (_) {
      // não guardou: o tema já mudou nesta abertura, e na próxima o app
      // volta ao que estava guardado. não vale um erro na tela
    }
  }
}
