import 'package:flutter/foundation.dart';
import 'package:managers/core/session/sessao_controller.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/assinatura/domain/usecases/assinatura_use_cases.dart';
import 'package:managers/features/auth/domain/usecases/logout_use_case.dart';

// estado da aba "Mais" (montado em home_provider.dart): a saída do app e se
// o item da assinatura aparece
class MaisProvider extends ChangeNotifier {
  MaisProvider({
    required this._logout,
    required this._sessao,
    required this._obterAssinatura,
    this.compraNoApp = true,
  });

  final LogoutUseCase _logout;
  final SessaoController _sessao;
  final ObterAssinaturaUseCase _obterAssinatura;

  // false no iPhone: lá o app não vende assinatura (a Apple não aceita
  // pagamento de fora), então o item nem aparece
  final bool compraNoApp;

  bool _saindo = false;
  bool get saindo => _saindo;

  bool _checkoutAberto = false;

  // na fase de testes (checkout fechado na API) não se fala de assinatura:
  // o item some do menu, no Android e no iPhone. fica escondido enquanto
  // carrega e se a API falhar; a tela continua existindo para o 402
  bool get mostraAssinatura => compraNoApp && _checkoutAberto;

  // a tela pode ser fechada durante a requisição
  bool _disposed = false;

  Future<void> carregar() async {
    if (!compraNoApp) return;

    final result = await _obterAssinatura(NoParams());
    if (_disposed) return;

    _checkoutAberto = result.fold((_) => false, (a) => a.checkoutAberto);
    notifyListeners();
  }

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
