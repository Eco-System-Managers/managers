import 'package:flutter/material.dart';

import '../widgets/login_form.dart';
import '../widgets/register_form.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool showLogin = true;

  // Função que altera os widgets login e cadastro
  void _toggleForm(){
    setState((){
      showLogin = !showLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Column(
        children: [
          const Expanded(child: Placeholder()),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: showLogin
                ? LoginForm(
                    key: const ValueKey('login'),
                    onSwitchToRegister: _toggleForm,
                  )
                : RegisterForm(
                    key: const ValueKey('register'),
                    onSwitchToLogin: _toggleForm,
                  ),
          ),
        ],
      ),
    );
  }
}