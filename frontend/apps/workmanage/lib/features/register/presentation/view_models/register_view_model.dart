import 'package:flutter/foundation.dart';

import '../../domain/params/register_param.dart';
import '../../domain/usecases/register_use_case.dart';

// estado da tela de cadastro: recebe o use case pelo construtor
// (montado em register_injection.dart)
class RegisterViewModel extends ChangeNotifier {
  RegisterViewModel(this._registerUseCase);

  final RegisterUseCase _registerUseCase;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // mensagem da última falha (null quando não houve erro)
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // a tela pode ser fechada durante a requisição
  bool _disposed = false;

  // ação chamada pela tela: devolve true se o cadastro deu certo
  Future<bool> register({
    required String nomeEmpresa,
    required String nome,
    required String email,
    required String senha,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final params = RegisterParam(
      nomeEmpresa: nomeEmpresa,
      nome: nome,
      email: email,
      senha: senha,
    );

    final result = await _registerUseCase(params);

    if (_disposed) return false;

    _isLoading = false;

    final success = result.fold((failure) {
      _errorMessage = failure.message;
      return false;
    }, (_) => true);

    notifyListeners();
    return success;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
