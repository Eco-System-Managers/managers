import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/session/sessao_provider.dart';
import 'package:managers/features/auth/presentation/pages/login_page.dart';
import 'package:managers/features/auth/presentation/pages/recovery_page.dart';
import 'package:managers/features/home/presentation/pages/home_page.dart';
import 'package:managers/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:managers/features/register/presentation/pages/register_page.dart';
import 'package:managers/features/register/presentation/pages/verify_email_page.dart';
import 'package:managers/features/splash/presentation/pages/splash_page.dart';

// o router é um provider para enxergar a sessão (ref)
final routerProvider = Provider<GoRouter>((ref) {
  final sessao = ref.watch(sessaoControllerProvider);

  final router = GoRouter(
    // o app sempre abre pela splash, que decide para onde ir
    initialLocation: '/splash',
    // quando a sessão muda (login, logout, 401 definitivo no interceptor),
    // o router reavalia o redirect: tela privada sem sessão volta ao login
    refreshListenable: sessao,
    redirect: (context, state) {
      // antes de a splash carregar a sessão guardada, não há o que decidir
      if (!sessao.carregada) return null;
      final destino = state.matchedLocation;
      if (!sessao.autenticado && !_publica(destino)) return '/login';
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (BuildContext context, GoRouterState state) {
          return const SplashPage();
        },
      ),
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginPage();
        },
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginPage();
        },
      ),
      GoRoute(
        path: '/recovery',
        pageBuilder: (BuildContext context, GoRouterState state) {
          return _authPanelPage(state, const RecoveryPage());
        },
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (BuildContext context, GoRouterState state) {
          return _authPanelPage(state, const RegisterPage());
        },
      ),
      // o e-mail vai na URL: a tela precisa dele para confirmar e reenviar
      GoRoute(
        path: '/register/verificar',
        pageBuilder: (BuildContext context, GoRouterState state) {
          return _authPanelPage(
            state,
            VerifyEmailPage(email: state.uri.queryParameters['email'] ?? ''),
          );
        },
      ),
      // página normal: o onboarding tem Scaffold e AppBar próprios, não usa
      // o painel animado das telas de auth
      GoRoute(
        path: '/onboarding',
        builder: (BuildContext context, GoRouterState state) {
          return const OnboardingPage();
        },
      ),
      GoRoute(
        path: '/home',
        builder: (BuildContext context, GoRouterState state) {
          return const HomePage();
        },
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

// as telas que abrem sem sessão: splash, login, recuperação e cadastro
bool _publica(String rota) {
  return rota == '/splash' ||
      rota == '/' ||
      rota == '/login' ||
      rota == '/recovery' ||
      rota.startsWith('/register');
}

// transição das telas de auth abertas a partir do login (cadastro e
// recuperação). o fundo delas é igual ao do login: o fade da página é só um
// instante no começo (ida) / no fim (volta), para trocar o conteúdo.
// o efeito principal é o painel crescendo/encolhendo (ver AuthPanel)
CustomTransitionPage<void> _authPanelPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 450),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation.drive(
          CurveTween(curve: const Interval(0, 0.25, curve: Curves.easeOut)),
        ),
        child: child,
      );
    },
  );
}
