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

  // TODO: Criar função que vai alterar o valor de showLogin e passar ao instanciar LoginForm() e RegisterForm()

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Column(
        children: [
          Expanded(child: Placeholder()),
          // TODO: Implementar navegação entre LoginForm e RegisterForm, usando botões.
          // TODO: Quando alternar fazer efeito visual smooth
          showLogin ? LoginForm() : RegisterForm(),

        ],
      ),
    );
  }
}
