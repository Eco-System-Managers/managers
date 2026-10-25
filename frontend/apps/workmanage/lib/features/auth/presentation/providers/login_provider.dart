import 'package:flutter/foundation.dart';
import 'package:managers/core/session/sessao_controller.dart';

import '../../domain/params/login_params.dart';
import '../../domain/usecases/login_use_case.dart';

// estado da tela de login (montado em auth_provider.dart). a validação
// dos campos fica na page, com o Validatorless
class LoginProvider extends ChangeNotifier {
  LoginProvider({required this._login, required this._sessao});

  final LoginUseCase _login;
  final SessaoController _sessao;

  // estado da tela (privado, só o provider altera)
  bool _isLoading = false;
  String? _errorMessage;

  // a tela pode ser fechada durante a requisição
  bool _disposed = false;

  // getters: a tela só consegue ler
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ação chamada pela tela: devolve true se entrou. a sessão já fica
  // guardada aqui; a tela só precisa seguir para a splash decidir a rota
  Future<bool> login(String email, String senha) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // avisa a tela: "estou carregando"

    final result = await _login(LoginParams(email: email, senha: senha));
    if (_disposed) return false;

    // o detail da API já é a mensagem para a pessoa ("E-mail ou senha
    // inválidos.", "Muitas tentativas..."), então ele é mostrado como veio
    final sessao = result.fold((failure) {
      _errorMessage = failure.message;
      return null;
    }, (sessao) => sessao);

    if (sessao != null) await _sessao.entrar(sessao);
    if (_disposed) return sessao != null;

    _isLoading = false;
    notifyListeners(); // avisa a tela: "terminei"
    return sessao != null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
