import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/params/reset_password_params.dart';
import '../../domain/params/verify_recovery_code_params.dart';
import '../../domain/usecases/reset_password_use_case.dart';
import '../../domain/usecases/send_recovery_code_use_case.dart';
import '../../domain/usecases/verify_recovery_code_use_case.dart';

// as etapas do fluxo de recuperação: a tela mostra uma de cada vez
enum RecoveryStep { email, code, newPassword, success }

// estado da tela de recuperação de senha (montado em auth_provider.dart).
// a validação dos campos fica na page, com o Validatorless
class RecoveryProvider extends ChangeNotifier {
  RecoveryProvider({
    required this._sendRecoveryCode,
    required this._verifyRecoveryCode,
    required this._resetPassword,
  });

  final SendRecoveryCodeUseCase _sendRecoveryCode;
  final VerifyRecoveryCodeUseCase _verifyRecoveryCode;
  final ResetPasswordUseCase _resetPassword;

  // o backend gera o código com 8 dígitos (core/models.py), o mesmo do
  // cadastro. usar o mesmo no `length` do pinput
  static const codeLength = 8;

  // estado da tela (privado, só o provider altera)
  RecoveryStep _step = RecoveryStep.email;
  bool _isLoading = false;
  String? _errorMessage;

  // guardados ao longo das etapas: a troca de senha precisa dos dois
  String _email = '';
  String _codigo = '';

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  // getters: a tela só consegue ler
  RecoveryStep get step => _step;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get email => _email;

  // etapa email -> code
  Future<void> sendCode(String email) async {
    // guarda antes da chamada: o reenvio e a troca de senha usam o mesmo e-mail
    _email = email.trim();
    await _run(() => _sendRecoveryCode(_email), () {
      _step = RecoveryStep.code;
    });
  }

  // etapa code -> newPassword
  Future<void> verifyCode(String codigo) async {
    final params = VerifyRecoveryCodeParams(email: _email, codigo: codigo);
    await _run(() => _verifyRecoveryCode(params), () {
      _codigo = codigo;
      _step = RecoveryStep.newPassword;
    });
  }

  // etapa newPassword -> success
  Future<void> resetPassword(String novaSenha) async {
    final params = ResetPasswordParams(
      email: _email,
      codigo: _codigo,
      novaSenha: novaSenha,
    );
    await _run(() => _resetPassword(params), () {
      _step = RecoveryStep.success;
    });
  }

  // na etapa code: reenvia para o mesmo e-mail, sem trocar de etapa
  Future<void> resendCode() async {
    await _run(() => _sendRecoveryCode(_email), () {});
  }

  // na etapa code: "errei o e-mail", volta para corrigir
  void backToEmail() {
    _step = RecoveryStep.email;
    _errorMessage = null; // o erro era da etapa do código, não vale mais
    notifyListeners();
  }

  // molde de toda ação: liga o loading, chama o use case e guarda o erro.
  // a mensagem é o detail da API ("Código inválido ou expirado.")
  Future<void> _run(
    Future<Either<Failure, void>> Function() acao,
    void Function() sucesso,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // avisa a tela: "estou carregando"

    final result = await acao();
    if (_disposed) return;

    result.fold((failure) => _errorMessage = failure.message, (_) => sucesso());

    _isLoading = false;
    notifyListeners(); // avisa a tela: "terminei" (e a etapa nova, se mudou)
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
