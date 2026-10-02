import 'package:flutter/foundation.dart';

class RegisterViewModel extends ChangeNotifier {
  // cada método recebe o texto do campo e devolve:
  //   null   -> válido
  //   string -> mensagem de erro que a tela vai exibir

  String? validateCompany(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe o nome da empresa';
    }
    return null;
  }

  String? validateOwner(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe seu nome';
    }
    return null;
  }

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Informe seu e-mail';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'E-mail inválido';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Informe uma senha';
    if (value.length < 6) return 'Mínimo de 6 caracteres';
    return null;
  }

  // precisa do valor da senha para comparar
  String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirme sua senha';
    if (value != password) return 'As senhas não conferem';
    return null;
  }
}
