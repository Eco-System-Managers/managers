import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:validatorless/validatorless.dart';

import '../../register_injection.dart';
import '../widgets/auth_logo.dart';
import '../widgets/auth_panel.dart';

// a tela lê o view model pelo ref (Riverpod), não recebe mais de fora
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  // o required do Validatorless aceita só espaços; isto exige um caractere
  static final _notBlank = RegExp(r'\S');

  // o email() do Validatorless recusa maiúsculas; os espaços nas pontas
  // são aceitos porque o _submit faz trim antes de enviar
  static final _emailPattern = RegExp(r'^\s*[^@\s]+@[^@\s]+\.[^@\s]+\s*$');

  // chave que dá acesso ao form para chamar validate()
  final _formKey = GlobalKey<FormState>();

  // controllers: um para cada campo de texto
  final _companyController = TextEditingController();
  final _ownerController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // cada campo de senha tem o seu próprio "olhinho"
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // libera a memória dos controllers quando a tela é destruída
  @override
  void dispose() {
    _companyController.dispose();
    _ownerController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = ref.read(registerViewModelProvider);

    final success = await viewModel.register(
      nomeEmpresa: _companyController.text.trim(),
      nome: _ownerController.text.trim(),
      email: _emailController.text.trim(),
      senha: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastro realizado com sucesso!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            viewModel.errorMessage ?? 'Não foi possível realizar o cadastro.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o view model vivo enquanto a tela estiver aberta
    final viewModel = ref.watch(registerViewModelProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,

      body: SafeArea(
        child: Column(
          children: [
            // área superior (logo/ilustração)
            const Expanded(child: AuthLogo(showName: false)),

            // painel inferior arredondado que contém o formulário
            AuthPanel(
              // form agrupa os campos e controla a validação
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Cadastro',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 24),

                    // nome da empresa
                    TextFormField(
                      controller: _companyController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: Validatorless.regex(
                        _notBlank,
                        'Informe a empresa',
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Nome da empresa',
                        prefixIcon: Icon(Icons.business_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // nome do proprietário
                    TextFormField(
                      controller: _ownerController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: Validatorless.regex(
                        _notBlank,
                        'Informe o nome',
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Seu nome',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

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

                    // senha
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      // mesmas regras do backend (validadores de senha do Django)
                      validator: Validatorless.multiple([
                        Validatorless.regex(_notBlank, 'Informe uma senha'),
                        Validatorless.min(8, 'Mínimo de 8 caracteres'),
                        Validatorless.regex(
                          RegExp(r'\D'),
                          'A senha não pode ter só números',
                        ),
                      ]),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),

                        // botão de "olhinho" da senha
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // confirmação de senha
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),

                      validator: Validatorless.multiple([
                        Validatorless.required('Confirme sua senha'),
                        Validatorless.compare(
                          _passwordController,
                          'As senhas não conferem',
                        ),
                      ]),

                      decoration: InputDecoration(
                        labelText: 'Confirmar senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),

                        // botão de "olhinho" da confirmação
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // botão de cadastrar: só ele se redesenha com o loading
                    ListenableBuilder(
                      listenable: viewModel,
                      builder: (context, _) => FilledButton(
                        onPressed: viewModel.isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: const Text('Cadastrar'),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // volta para o login (o painel encolhe de volta);
                    // se abriu direto no cadastro, não há o que desempilhar
                    TextButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/login'),
                      child: const Text('Fazer Login'),
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
