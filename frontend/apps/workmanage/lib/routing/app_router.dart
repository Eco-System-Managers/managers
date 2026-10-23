import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/features/auth/auth_provider.dart';
import 'package:managers/features/auth/presentation/providers/recovery_provider.dart';
import 'package:managers/features/auth/presentation/providers/login_provider.dart';
import 'package:managers/features/auth/presentation/pages/login_page.dart';
import 'package:managers/features/auth/presentation/pages/recovery_page.dart';
import 'package:managers/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:managers/features/register/presentation/pages/register_page.dart';
import 'package:managers/features/register/presentation/pages/verify_email_page.dart';
import 'package:managers/features/splash/presentation/providers/splash_provider.dart';
import 'package:managers/features/splash/presentation/pages/splash_page.dart';

// o router é um provider para as rotas conseguirem ler os use cases (ref)
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    // o app sempre abre pela splash, que decide para onde ir
    initialLocation: '/splash',
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (BuildContext context, GoRouterState state) {
          return SplashPage(provider: SplashProvider());
        },
      ),
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return LoginPage(
            provider: LoginProvider(ref.read(loginUseCaseProvider)),
          );
        },
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return LoginPage(
            provider: LoginProvider(ref.read(loginUseCaseProvider)),
          );
        },
      ),
      GoRoute(
        path: '/recovery',
        pageBuilder: (BuildContext context, GoRouterState state) {
          return _authPanelPage(
            state,
            RecoveryPage(
              provider: RecoveryProvider(
                sendRecoveryCode: ref.read(sendRecoveryCodeUseCaseProvider),
                verifyRecoveryCode: ref.read(verifyRecoveryCodeUseCaseProvider),
                resetPassword: ref.read(resetPasswordUseCaseProvider),
              ),
            ),
          );
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
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

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
