import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/ui/auth/widgets/login_screen.dart';
import 'package:managers/ui/auth/widgets/register_screen.dart';

final GoRouter router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginScreen(); // TODO: Substituir pela tela inicial
      },
    ),
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginScreen(); // TODO: Substituir pela tela de Login
      },
    ),
    GoRoute(
      path: '/register',
      builder: (BuildContext context, GoRouterState state) {
        return const RegisterScreen(); // TODO: Substituir pela tela de Registro
      },
    ),
  ],
);