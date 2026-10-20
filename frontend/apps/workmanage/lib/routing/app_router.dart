import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/ui/auth/view_models/recovery_view_model.dart';
import 'package:managers/ui/auth/view_models/register_view_model.dart';
import 'package:managers/ui/auth/view_models/login_view_model.dart';
import 'package:managers/ui/auth/widgets/login_screen.dart';
import 'package:managers/ui/auth/widgets/recovery_screen.dart';
import 'package:managers/ui/auth/widgets/register_screen.dart';
import 'package:managers/ui/splash/view_models/splash_view_model.dart';
import 'package:managers/ui/splash/widgets/splash_screen.dart';

final GoRouter router = GoRouter(
  // o app sempre abre pela splash, que decide para onde ir
  initialLocation: '/splash',
  routes: <RouteBase>[
    GoRoute(
      path: '/splash',
      builder: (BuildContext context, GoRouterState state) {
        return SplashScreen(viewModel: SplashViewModel());
      },
    ),
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return LoginScreen(viewModel: LoginViewModel());
      },
    ),
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        return LoginScreen(viewModel: LoginViewModel());
      },
    ),
    GoRoute(
      path: '/recovery',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _authPanelPage(
          state,
          RecoveryScreen(viewModel: RecoveryViewModel()),
        );
      },
    ),
    GoRoute(
      path: '/register',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _authPanelPage(
          state,
          RegisterScreen(viewModel: RegisterViewModel()),
        );
      },
    ),
  ],
);

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
