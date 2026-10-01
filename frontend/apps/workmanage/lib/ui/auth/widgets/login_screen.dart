import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Column(
        children: [
          const Expanded(child: Placeholder()),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bem-vindo de volta',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                ElevatedButton(
                  // Chama a função do pai, que troca para o RegisterForm
                  onPressed: () {},
                  child: const Text('Criar conta'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
