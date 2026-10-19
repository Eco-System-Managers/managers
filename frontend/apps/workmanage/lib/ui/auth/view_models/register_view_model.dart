import 'package:flutter/foundation.dart';

class RegisterViewModel extends ChangeNotifier {
  // cada método recebe o texto do campo e devolve:
  //   null   -> válido
  //   string -> mensagem de erro que a tela vai exibir

  String? validateCompany(String? value) {
    if (_isEmpty(value)) return "Informe a empresa";
    return null;
  }

  String? validateOwner(String? value) {
    if (_isEmpty(value)) return "Informe o nome";
    return null;
  }

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (_isEmpty(email)) return 'Informe seu e-mail';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'E-mail inválido';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (_isEmpty(value)) return 'Informe uma senha';
    if (value!.length < 6) return 'Mínimo de 6 caracteres';
    return null;
  }

  // precisa do valor da senha para comparar
  String? validateConfirmPassword(String? value, String password) {
    if (_isEmpty(value)) return 'Confirme sua senha';
    if (value != password) return 'As senhas não conferem';
    return null;
  }

  bool _isEmpty (String? value){
    if (value == null || value.trim().isEmpty){
      return true;
    }
    return false;
  }
}
