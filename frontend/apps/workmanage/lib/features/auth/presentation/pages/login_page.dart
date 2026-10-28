import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/features/usuarios/presentation/widgets/convite_link_dialog.dart';
import 'package:managers/core/widgets/auth_logo.dart';
import 'package:managers/core/widgets/auth_panel.dart';
import 'package:validatorless/validatorless.dart';

import '../../auth_provider.dart';

// a tela lê o provider pelo ref (Riverpod), como as demais
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  // o required do Validatorless aceita só espaços; isto exige um caractere
  static final _notBlank = RegExp(r'\S');

  // o email() do Validatorless recusa maiúsculas; os espaços nas pontas
  // são aceitos porque o _submit faz trim antes de enviar
  static final _emailPattern = RegExp(r'^\s*[^@\s]+@[^@\s]+\.[^@\s]+\s*$');

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

    // entrega os textos digitados para o provider
    final ok = await ref
        .read(loginProvider)
        .login(_emailController.text.trim(), _passwordController.text);

    // se a tela foi fechada durante a espera, não faz mais nada
    if (!mounted) return;

    // a sessão já está guardada: a splash decide entre onboarding e home
    if (ok) context.go('/splash');
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(loginProvider);

    return Scaffold(
      backgroundColor: BrandColors.brandNavy,

      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: estiloDaBarraDeAbertura,
        child: SafeArea(
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
                        validator: Validatorless.multiple([
                          Validatorless.regex(_notBlank, 'Informe seu e-mail'),
                          Validatorless.regex(_emailPattern, 'E-mail inválido'),
                        ]),
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // senha: só exigimos que não esteja vazia, quem confere
                      // é o backend
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,

                        // enter no teclado também tenta entrar
                        onFieldSubmitted: (_) => _submit(),

                        validator: Validatorless.required('Informe sua senha'),
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

                      // mensagem de erro do provider (só aparece se houver)
                      ListenableBuilder(
                        listenable: provider,
                        builder: (context, _) {
                          final error = provider.errorMessage;

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
                        listenable: provider,
                        builder: (context, _) {
                          final loading = provider.isLoading;

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
                      // quem recebeu convite da equipe cola o link do e-mail
                      // (sem deep link ainda)
                      TextButton(
                        onPressed: () => abrirConvitePorLink(context),
                        child: const Text('Recebi um convite da equipe'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
