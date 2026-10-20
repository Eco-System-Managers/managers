import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/ui/auth/view_models/login_view_model.dart';
import 'package:managers/ui/auth/widgets/auth_logo.dart';
import 'package:managers/ui/auth/widgets/auth_panel.dart';

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

      body: SafeArea(
        child: Column(
          children: [
            // área superior: logo completo (símbolo + texto)
            const Expanded(child: AuthLogo()),
            // painel inferior arredondado que contém o formulário
            AuthPanel(
              // form agrupa os campos e controla a validação
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Bem-vindo de volta',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
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

                    // link para a tela de recuperação, alinhado à direita
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        // push mantém o login na pilha, então o voltar funciona
                        onPressed: () => context.push('/recovery'),
                        child: const Text('Esqueci minha senha'),
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

                    // navega para a tela de cadastro; push mantém o login
                    // embaixo, para o painel animar na ida e na volta
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('Criar conta'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
