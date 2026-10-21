import 'package:flutter/foundation.dart';

/// Decide para onde ir depois da splash.
/// Espera a inicialização do app E pelo menos um ciclo da animação.
class SplashProvider extends ChangeNotifier {
  SplashProvider({Future<bool> Function()? isLoggedIn})
      : _isLoggedIn = isLoggedIn ?? (() async => false);

  final Future<bool> Function() _isLoggedIn;

  String? _nextRoute;
  bool _cycleDone = false;

  /// Rota de destino quando estiver tudo pronto; null enquanto carrega.
  String? get destination => (_cycleDone && _nextRoute != null) ? _nextRoute : null;

  Future<void> init() async {
    // TODO: coloque aqui o que precisa estar pronto antes de abrir o app
    // (ler token salvo, carregar config remota, etc.).
    try {
      final logged = await _isLoggedIn();
      _nextRoute = logged ? '/home' : '/login';
    } catch (e) {
      // se a inicialização falhar, manda para o login em vez de travar na splash
      _nextRoute = '/login';
    } finally {
      notifyListeners();
    }
  }

  void onAnimationCycleEnd() {
    if (_cycleDone) return;
    _cycleDone = true;
    notifyListeners();
  }
}
