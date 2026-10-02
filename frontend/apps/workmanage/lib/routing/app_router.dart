import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/ui/auth/view_models/register_view_model.dart';
import 'package:managers/ui/auth/view_models/login_view_model.dart';
import 'package:managers/ui/auth/widgets/login_screen.dart';
import 'package:managers/ui/auth/widgets/register_screen.dart';

final GoRouter router = GoRouter(
  routes: <RouteBase>[
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
      path: '/register',
      builder: (BuildContext context, GoRouterState state) {
        // cria o viewmodel e entrega para a tela de registro
        return RegisterScreen(viewModel: RegisterViewModel());
      },
    ),
  ],
);