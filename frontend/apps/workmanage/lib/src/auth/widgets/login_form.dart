import 'package:flutter/material.dart';

class LoginForm extends StatelessWidget {
  // Atributo que guarda a função recebida do pai (AuthScreen)
  final VoidCallback onSwitchToRegister;

  // "required this." liga o parâmetro ao atributo acima e torna obrigatório
  const LoginForm({super.key, required this.onSwitchToRegister});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            onPressed: onSwitchToRegister,
            child: const Text('Criar conta'),
          ),
        ],
      ),
    );
  }
}