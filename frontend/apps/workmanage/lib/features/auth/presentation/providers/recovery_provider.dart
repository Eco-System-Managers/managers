import 'package:flutter/foundation.dart';

import '../../domain/usecases/reset_password_use_case.dart';
import '../../domain/usecases/send_recovery_code_use_case.dart';
import '../../domain/usecases/verify_recovery_code_use_case.dart';

// as etapas do fluxo de recuperação: a tela mostra uma de cada vez
enum RecoveryStep { email, code, newPassword, success }

class RecoveryProvider extends ChangeNotifier {
  RecoveryProvider({
    required SendRecoveryCodeUseCase sendRecoveryCode,
    required VerifyRecoveryCodeUseCase verifyRecoveryCode,
    required ResetPasswordUseCase resetPassword,
  }) : _sendRecoveryCode = sendRecoveryCode,
       _verifyRecoveryCode = verifyRecoveryCode,
       _resetPassword = resetPassword;

  final SendRecoveryCodeUseCase _sendRecoveryCode;
  final VerifyRecoveryCodeUseCase _verifyRecoveryCode;
  final ResetPasswordUseCase _resetPassword;

  // tamanho do código enviado por e-mail (usar o mesmo no `length` do pinput)
  static const codeLength = 6;

  // estado da tela (privado, só o provider altera)
  RecoveryStep _step = RecoveryStep.email;
  bool _isLoading = false;
  String? _errorMessage;
  // guardado na etapa do e-mail e usado de novo na troca de senha
  String _email = '';

  // getters: a tela só consegue ler
  RecoveryStep get step => _step;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get email => _email;

  // validators: devolvem null (válido) ou a mensagem de erro
  // TODO: mover para o arquivo compartilhado em lib/core/utils/
  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (_isEmpty(email)) return 'Informe seu e-mail';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'E-mail inválido';
    }
    return null;
  }

  String? validateCode(String? value) {
    final code = value?.trim() ?? '';
    if (_isEmpty(code)) return 'Informe o código';
    if (code.length != codeLength || !RegExp(r'^\d+$').hasMatch(code)) {
      return 'O código tem $codeLength dígitos';
    }
    return null;
  }

  // mesma regra do cadastro: a senha nova precisa ter no mínimo 6 caracteres
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

  // etapa email -> code
  Future<void> sendCode(String email) async {
    // guarda antes da chamada: o reenvio e a troca de senha usam o mesmo e-mail
    _email = email.trim();
    await _run(
      errorMessage: 'Não foi possível enviar o código. Tente novamente.',
      action: () async {
        await _sendRecoveryCode(_email);
        _step = RecoveryStep.code;
      },
    );
  }

  // etapa code -> newPassword
  Future<void> verifyCode(String code) async {
    await _run(
      errorMessage: 'Código inválido ou expirado.',
      action: () async {
        await _verifyRecoveryCode(code);
        _step = RecoveryStep.newPassword;
      },
    );
  }

  // etapa newPassword -> success
  Future<void> resetPassword(String password) async {
    await _run(
      errorMessage: 'Não foi possível alterar a senha. Tente novamente.',
      action: () async {
        await _resetPassword(_email, password);
        _step = RecoveryStep.success;
      },
    );
  }

  // na etapa code: reenvia para o mesmo e-mail, sem trocar de etapa
  Future<void> resendCode() async {
    await _run(
      errorMessage: 'Não foi possível reenviar o código. Tente novamente.',
      action: () async {
        await _sendRecoveryCode(_email);
      },
    );
  }

  // na etapa code: "errei o e-mail", volta para corrigir
  void backToEmail() {
    _step = RecoveryStep.email;
    _errorMessage = null; // o erro era da etapa do código, não vale mais
    notifyListeners();
  }

  // molde de toda ação: mesmo fluxo do LoginProvider.login
  Future<void> _run({
    required String errorMessage,
    required Future<void> Function() action,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // avisa a tela: "estou carregando"

    try {
      await action();
    } catch (e) {
      _errorMessage = errorMessage;
    } finally {
      // o finally roda sempre, dando certo ou não
      _isLoading = false;
      notifyListeners(); // avisa a tela: "terminei" (e a etapa nova, se mudou)
    }
  }

  bool _isEmpty(String? value) => value == null || value.trim().isEmpty;
}
