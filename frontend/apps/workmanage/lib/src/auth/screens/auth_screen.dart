import 'package:flutter/material.dart';
import 'package:managers/src/auth/widgets/auth_form.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Column(
        children: [
          Expanded(child: Placeholder()),
          AuthForm(),
        ],
      ),
    );
  }
}
