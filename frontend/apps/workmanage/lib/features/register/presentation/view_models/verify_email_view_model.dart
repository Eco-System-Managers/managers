import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/params/confirm_param.dart';
import '../../domain/usecases/confirm_register_use_case.dart';
import '../../domain/usecases/resend_code_use_case.dart';

// estado da tela "Verifique seu e-mail": confirmar o código e reenviar
// (montado em register_injection.dart)
class VerifyEmailViewModel extends ChangeNotifier {
  VerifyEmailViewModel(this._confirmRegister, this._resendCode) {
    // a tela abre logo depois do envio: o primeiro reenvio já espera
    _startCooldown();
  }

  final ConfirmRegisterUseCase _confirmRegister;
  final ResendCodeUseCase _resendCode;

  // o backend gera o código com 8 dígitos (core/models.py)
  static const codeLength = 8;

  // o backend aceita 3 envios por minuto; esperar evita cair no limite
  static const resendCooldown = 60;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // mensagem da última falha (null quando não houve erro)
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // aviso de sucesso do reenvio
  String? _infoMessage;
  String? get infoMessage => _infoMessage;

  // segundos até poder reenviar; 0 libera o botão
  int _secondsLeft = 0;
  int get secondsLeft => _secondsLeft;

  Timer? _timer;

  // a tela pode ser fechada durante a requisição
  bool _disposed = false;

  // devolve true se o código conferiu (a empresa foi criada)
  Future<bool> confirm({required String email, required String code}) async {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    final result = await _confirmRegister(
      ConfirmParam(email: email, code: code),
    );

    if (_disposed) return false;

    _isLoading = false;

    final success = result.fold((failure) {
      _errorMessage = failure.message;
      return false;
    }, (_) => true);

    notifyListeners();
    return success;
  }

  Future<void> resend(String email) async {
    if (_secondsLeft > 0) return;

    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    final result = await _resendCode(email);

    if (_disposed) return;

    _isLoading = false;

    result.fold((failure) => _errorMessage = failure.message, (_) {
      _infoMessage = 'Enviamos um novo código.';
      _startCooldown();
    });

    notifyListeners();
  }

  void _startCooldown() {
    _timer?.cancel();
    _secondsLeft = resendCooldown;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsLeft--;
      if (_secondsLeft <= 0) timer.cancel();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
