import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // controller = "ponte" para ler o que o usuário digitou no campo
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // controla se a senha está escondida (true) ou visível (false)
  bool _obscurePassword = true;

  // libera a memória dos controllers quando a tela é destruída
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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

            // painel inferior arredondado que contém o formulário de login
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Bem-vindo de volta',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16), // espaçamento

                TextField(
                  controller:
                      _passwordController, // liga ao controller da senha
                  obscureText: _obscurePassword, // true = esconde os caracteres
                  textInputAction:
                      TextInputAction.done, // Enter finaliza a digitação
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    // Botão de "olhinho" no final do campo
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons
                                  .visibility_outlined // senha escondida
                            : Icons.visibility_off_outlined, // senha visível
                      ),
                      onPressed: () {
                        // setState avisa o Flutter para redesenhar a tela com o novo valor
                        setState(() {
                          _obscurePassword =
                              !_obscurePassword; // inverte true/false
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 24), // espaçamento

                // botão de entrar
                FilledButton(
                  
                  onPressed: () {
                    final email = _emailController.text.trim();
                    final senha = _passwordController.text;

                    // TODO: enviar email e senha para o ViewModel / backend
                    
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(
                      52,
                    ), 
                  ),
                  child: const Text('Entrar'),
                ),

                const SizedBox(height: 8), // espaçamento

                // botão de cadastro
                TextButton(
                  onPressed: () => context.go('/register'),
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
