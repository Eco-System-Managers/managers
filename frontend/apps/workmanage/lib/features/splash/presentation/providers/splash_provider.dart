import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao_controller.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_config_use_case.dart';

/// Decide para onde ir depois da splash: sem sessão guardada, login; com
/// sessão e onboarding por concluir, o wizard; senão, a home.
/// A navegação só sai no fim de um ciclo da animação: se a decisão chega no
/// meio de um ciclo, espera ele terminar, para o símbolo não ser cortado.
class SplashProvider extends ChangeNotifier {
  SplashProvider({required this._sessao, required this._buscarConfig});

  final SessaoController _sessao;
  final BuscarConfigUseCase _buscarConfig;

  String? _nextRoute;
  bool _pronto = false;

  // a tela pode ser fechada durante a decisão
  bool _disposed = false;

  /// A rota já foi decidida. A tela usa isto para a animação parar de
  /// repetir e terminar o ciclo que está rodando.
  bool get rotaDecidida => _nextRoute != null;

  /// Rota de destino quando estiver tudo pronto (rota decidida e um ciclo da
  /// animação terminado depois dela); null enquanto carrega.
  String? get destination => _pronto ? _nextRoute : null;

  Future<void> init() async {
    try {
      // só na abertura do app: depois do login a sessão já está em memória
      if (!_sessao.carregada) await _sessao.carregar();
      _nextRoute = _sessao.autenticado ? await _rotaComSessao() : '/login';
    } catch (_) {
      // se a inicialização falhar, manda para o login em vez de travar na splash
      _nextRoute = '/login';
    }
    if (_disposed) return;
    notifyListeners();
  }

  // a config diz se o onboarding foi concluído. se a API não responder
  // (rede), a home abre e mostra o próprio erro; se a sessão não valer
  // mais, o interceptor já a limpou e o caminho é o login
  Future<String> _rotaComSessao() async {
    final result = await _buscarConfig(NoParams());
    return result.fold(
      (failure) => failure is AuthFailure ? '/login' : '/home',
      (config) => config.onboardingConcluido ? '/home' : '/onboarding',
    );
  }

  /// O fim de um ciclo da animação: com a rota decidida, libera a navegação;
  /// sem ela, a animação repete e o próximo fim de ciclo tenta de novo.
  void onAnimationCycleEnd() {
    if (_pronto || _nextRoute == null) return;
    _pronto = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
