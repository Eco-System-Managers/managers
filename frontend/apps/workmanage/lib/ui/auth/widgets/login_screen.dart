import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/ui/auth/view_models/login_view_model.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.viewModel});

  // a tela recebe o viewmodel de fora (vem do app_router.dart)
  final LoginViewModel viewModel;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // chave que dá acesso ao form para chamar validate()
  final _formKey = GlobalKey<FormState>();

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

  Future<void> _submit() async {
    // roda os validators; se algum falhar, os erros aparecem nos campos
    if (!_formKey.currentState!.validate()) return;

    // entrega os textos digitados para o viewmodel
    final ok = await widget.viewModel.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    // se a tela foi fechada durante a espera, não faz mais nada
    if (!mounted) return;

    if (ok) {
      // TODO: navegar para a tela principal (context.go('/home'))
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,

      // fundo da tela inteira
      body: Stack(
        children: [
          // FUNDO
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/images/backgroundPattern.svg',
              fit: BoxFit.cover,
            ),
          ),

          // CONTEÚDO
          Column(
            children: [
              // área superior (logo/ilustração)
              const Expanded(child: SizedBox()),
              // painel inferior arredondado que contém o formulário
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),

                // form agrupa os campos e controla a validação
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Bem-vindo de volta',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // e-mail
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: widget.viewModel.validateEmail,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // senha
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,

                        // enter no teclado também tenta entrar
                        onFieldSubmitted: (_) => _submit(),

                        validator: widget.viewModel.validatePassword,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),

                          // botão de "olhinho" no final do campo
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              // setState avisa o flutter para redesenhar
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),

                      // mensagem de erro do viewmodel (só aparece se houver)
                      ListenableBuilder(
                        listenable: widget.viewModel,
                        builder: (context, _) {
                          final error = widget.viewModel.errorMessage;

                          if (error == null) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              error,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // botão de entrar: reage ao estado de loading
                      ListenableBuilder(
                        listenable: widget.viewModel,
                        builder: (context, _) {
                          final loading = widget.viewModel.isLoading;

                          return FilledButton(
                            // null desabilita o botão durante o loading
                            onPressed: loading ? null : _submit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Entrar'),
                          );
                        },
                      ),

                      const SizedBox(height: 8),

                      // navega para a tela de cadastro
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('Criar conta'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
