import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../view_models/register_view_model.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.viewModel});

  // a tela recebe o viewmodel de fora (vem do app_router.dart)
  final RegisterViewModel viewModel;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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

  void _submit() {
    // roda todos os validators; se algum falhar, os erros aparecem nos campos
    if (!_formKey.currentState!.validate()) return;

    final empresa = _companyController.text.trim();
    final proprietario = _ownerController.text.trim();
    final email = _emailController.text.trim();

    // TODO: enviar para o viewmodel / backend
    // o debugPrint abaixo serve apenas para teste (não imprime a senha)
    debugPrint('Cadastro: $empresa / $proprietario / $email');
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
          SafeArea(
            child: Column(
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
                          'Cadastro',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // nome da empresa
                        TextFormField(
                          controller: _companyController,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: widget.viewModel.validateCompany,
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
                          validator: widget.viewModel.validateOwner,
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
                          textInputAction: TextInputAction.next,
                          validator: widget.viewModel.validatePassword,
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

                          // a tela entrega a senha digitada para comparar
                          validator: (value) =>
                              widget.viewModel.validateConfirmPassword(
                                value,
                                _passwordController.text,
                              ),

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

                        // botão de cadastrar
                        FilledButton(
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          child: const Text('Cadastrar'),
                        ),

                        const SizedBox(height: 8),

                        // navega para a tela de login
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Fazer Login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
