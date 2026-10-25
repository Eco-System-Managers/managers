import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao_controller.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/onboarding/domain/usecases/buscar_config_use_case.dart';

/// Decide para onde ir depois da splash: sem sessão guardada, login; com
/// sessão e onboarding por concluir, o wizard; senão, a home.
/// Espera a decisão E pelo menos um ciclo da animação.
class SplashProvider extends ChangeNotifier {
  SplashProvider({required this._sessao, required this._buscarConfig});

  final SessaoController _sessao;
  final BuscarConfigUseCase _buscarConfig;

  String? _nextRoute;
  bool _cycleDone = false;

  // a tela pode ser fechada durante a decisão
  bool _disposed = false;

  /// Rota de destino quando estiver tudo pronto; null enquanto carrega.
  String? get destination =>
      (_cycleDone && _nextRoute != null) ? _nextRoute : null;

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

  void onAnimationCycleEnd() {
    if (_cycleDone) return;
    _cycleDone = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
