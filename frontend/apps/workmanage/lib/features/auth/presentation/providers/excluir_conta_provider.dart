import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao_controller.dart';

import '../../domain/usecases/excluir_conta_use_case.dart';

// estado da tela de excluir a conta (montado em auth_provider.dart). deu
// certo, a sessão acaba aqui mesmo e o router leva ao login
class ExcluirContaProvider extends ChangeNotifier {
  ExcluirContaProvider({required this._excluir, required this._sessao});

  final ExcluirContaUseCase _excluir;
  final SessaoController _sessao;

  bool _isLoading = false;
  String? _errorMessage;
  String? _erroSenha;

  // a tela pode ser fechada durante a requisição
  bool _disposed = false;

  bool get isLoading => _isLoading;

  // erro que não é da senha (rede, cobrança que o gateway não cancelou)
  String? get errorMessage => _errorMessage;

  // senha errada vai para o campo
  String? get erroSenha => _erroSenha;

  void limparErroSenha() {
    if (_erroSenha == null) return;
    _erroSenha = null;
    notifyListeners();
  }

  Future<void> excluir(String senha) async {
    _isLoading = true;
    _errorMessage = null;
    _erroSenha = null;
    notifyListeners();

    final result = await _excluir(senha);
    if (_disposed) return;

    final excluiu = result.fold((failure) {
      if (failure.code == 'senha_incorreta') {
        _erroSenha = failure.message;
      } else if (failure is ValidationFailure &&
          (failure.fields['senha']?.isNotEmpty ?? false)) {
        _erroSenha = failure.fields['senha']!.first;
      } else {
        _errorMessage = failure.message;
      }
      return false;
    }, (_) => true);

    // a API já encerrou as sessões: aqui só se limpa a local
    if (excluiu) await _sessao.sair();
    if (_disposed) return;

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
