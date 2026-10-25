import 'package:flutter/foundation.dart';
import 'package:managers/core/session/sessao_controller.dart';
import 'package:managers/features/auth/domain/usecases/logout_use_case.dart';

// estado da aba "Mais" (montado em home_provider.dart): a saída do app
class MaisProvider extends ChangeNotifier {
  MaisProvider({required this._logout, required this._sessao});

  final LogoutUseCase _logout;
  final SessaoController _sessao;

  bool _saindo = false;
  bool get saindo => _saindo;

  // a tela pode ser fechada durante a requisição
  bool _disposed = false;

  // revoga o refresh na API e limpa a sessão local. se a API falhar (rede,
  // sessão já encerrada por lá), a sessão local é limpa do mesmo jeito: o
  // router escuta a sessão e leva ao login
  Future<void> sair() async {
    final sessao = _sessao.atual;
    if (sessao == null || _saindo) return;

    _saindo = true;
    notifyListeners();

    await _logout(sessao.refresh);
    if (_disposed) return;

    await _sessao.sair();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
