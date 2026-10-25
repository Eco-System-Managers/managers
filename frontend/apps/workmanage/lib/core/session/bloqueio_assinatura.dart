import 'package:flutter/foundation.dart';

// o aviso de assinatura bloqueada (402 assinatura_bloqueada), para o app
// inteiro: o interceptor marca quando qualquer requisição leva 402, o
// router leva à tela de assinatura, e a tela limpa quando a assinatura
// volta a valer. a sessão acabando também limpa
class BloqueioAssinatura extends ChangeNotifier {
  String? _mensagem;

  bool get bloqueada => _mensagem != null;

  // o detail que a API mandou, para a tela mostrar
  String? get mensagem => _mensagem;

  void marcar(String mensagem) {
    if (_mensagem == mensagem) return;
    _mensagem = mensagem;
    notifyListeners();
  }

  void limpar() {
    if (_mensagem == null) return;
    _mensagem = null;
    notifyListeners();
  }
}
