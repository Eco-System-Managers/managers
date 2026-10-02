import 'package:flutter/foundation.dart';

class LoginViewModel extends ChangeNotifier {
  // estado da tela (privado, só o viewmodel altera)
  bool _isLoading = false;
  String? _errorMessage;

  // getters: a tela só consegue ler
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // validators: devolvem null (válido) ou a mensagem de erro
  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Informe seu e-mail';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'E-mail inválido';
    }
    return null;
  }

  String? validatePassword(String? value) {
    // no login só exigimos que não esteja vazia: quem confere a senha é o backend
    if (value == null || value.isEmpty) return 'Informe sua senha';
    return null;
  }

  // ação chamada pela tela: devolve true se o login deu certo
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // avisa a tela: "estou carregando"

    try {
      // TODO: chamar o authrepository (data/repositories)
      await Future.delayed(const Duration(seconds: 1)); // simulação
      return true;
    } catch (e) {
      _errorMessage = 'Não foi possível entrar. Tente novamente.';
      return false;
    } finally {
      // o finally roda sempre, dando certo ou não
      _isLoading = false;
      notifyListeners(); // avisa a tela: "terminei"
    }
  }
}
