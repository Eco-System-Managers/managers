import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/widgets/auth_logo.dart';
import 'package:managers/core/widgets/auth_panel.dart';
import 'package:managers/core/widgets/success_view.dart';
import 'package:pinput/pinput.dart';
import 'package:validatorless/validatorless.dart';

import '../../auth_provider.dart';
import '../providers/recovery_provider.dart';

// a tela lê o provider pelo ref (Riverpod), como as demais
class RecoveryPage extends ConsumerStatefulWidget {
  const RecoveryPage({super.key});

  @override
  ConsumerState<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends ConsumerState<RecoveryPage> {
  // o required do Validatorless aceita só espaços; isto exige um caractere
  static final _notBlank = RegExp(r'\S');

  // o email() do Validatorless recusa maiúsculas; os espaços nas pontas
  // são aceitos porque o provider faz trim antes de enviar
  static final _emailPattern = RegExp(r'^\s*[^@\s]+@[^@\s]+\.[^@\s]+\s*$');

  static const _codeLength = RecoveryProvider.codeLength;

  // um form só: em cada etapa, só os campos visíveis entram no validate()
  final _formKey = GlobalKey<FormState>();

  // controllers de todas as etapas
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // controla se cada senha está escondida (true) ou visível (false)
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  RecoveryProvider get _provider => ref.read(recoveryProvider);

  // libera a memória dos controllers quando a tela é destruída
  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // cada ação valida o form e entrega o valor para o provider.
  // a troca de etapa é decidida lá: a tela só redesenha pelo ListenableBuilder
  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    await _provider.sendCode(_emailController.text);
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    await _provider.verifyCode(_codeController.text);
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    await _provider.resetPassword(_passwordController.text);
  }

  Future<void> _resendCode() async {
    // o código antigo não vale mais
    _codeController.clear();
    await _provider.resendCode();
  }

  void _changeEmail() {
    _codeController.clear();
    _provider.backToEmail();
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(recoveryProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,

      body: SafeArea(
        child: Column(
          children: [
            // botão de voltar: o login abriu esta tela com push, então ele volta
            Align(
              alignment: Alignment.centerLeft,
              child: BackButton(color: Theme.of(context).colorScheme.onPrimary),
            ),
            // área superior: logo completo (símbolo + texto)
            const Expanded(child: AuthLogo()),
            // painel inferior arredondado, igual ao do login
            AuthPanel(
              child: Form(
                key: _formKey,
                // redesenha o painel sempre que o provider avisar
                // (troca de etapa, loading ou erro)
                child: ListenableBuilder(
                  listenable: provider,
                  builder: (context, _) {
                    // mostra só a etapa atual
                    return switch (provider.step) {
                      RecoveryStep.email => _emailStep(provider),
                      RecoveryStep.code => _codeStep(provider),
                      RecoveryStep.newPassword => _newPasswordStep(provider),
                      RecoveryStep.success => _successStep(),
                    };
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ETAPA 1: e-mail
  Widget _emailStep(RecoveryProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          'Recuperar senha',
          'Informe o e-mail da sua conta e enviaremos um código de verificação.',
        ),

        const SizedBox(height: 24),

        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          // enter no teclado também envia
          onFieldSubmitted: (_) => _sendCode(),
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

        _errorMessage(provider),

        const SizedBox(height: 24),

        _submitButton(provider, 'Enviar código', _sendCode),
      ],
    );
  }

  // ETAPA 2: código de verificação
  Widget _codeStep(RecoveryProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final loading = provider.isLoading;

    // aparência de cada caixinha do código
    final pinTheme = PinTheme(
      width: 40,
      height: 52,
      textStyle: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(8),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          'Verificar código',
          'Digite o código de $_codeLength dígitos '
              'enviado para ${provider.email}.',
        ),

        const SizedBox(height: 24),

        // 8 caixinhas não cabem em celular estreito:
        // o FittedBox encolhe em vez de estourar a tela
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Pinput(
            length: _codeLength,
            controller: _codeController,
            autofocus: true,
            enabled: !loading,
            defaultPinTheme: pinTheme,
            // caixinha em foco ganha a cor da marca
            focusedPinTheme: pinTheme.copyBorderWith(
              border: Border.all(color: colors.primary, width: 2),
            ),
            separatorBuilder: (_) => const SizedBox(width: 6),
            validator: Validatorless.multiple([
              Validatorless.required('Informe o código'),
              Validatorless.number('O código tem só números'),
              Validatorless.length(
                _codeLength,
                'O código tem $_codeLength dígitos',
              ),
            ]),
            // ao digitar o último dígito, já verifica
            onCompleted: (_) => _verifyCode(),
          ),
        ),

        _errorMessage(provider),

        const SizedBox(height: 24),

        _submitButton(provider, 'Verificar', _verifyCode),

        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: loading ? null : _changeEmail,
              child: const Text('Trocar e-mail'),
            ),
            TextButton(
              onPressed: loading ? null : _resendCode,
              child: const Text('Reenviar código'),
            ),
          ],
        ),
      ],
    );
  }

  // ETAPA 3: nova senha
  Widget _newPasswordStep(RecoveryProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header('Nova senha', 'Crie uma nova senha para acessar sua conta.'),

        const SizedBox(height: 24),

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
            labelText: 'Nova senha',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _resetPassword(),
          // compara com o que está no campo de senha agora
          validator: Validatorless.multiple([
            Validatorless.required('Confirme sua senha'),
            Validatorless.compare(
              _passwordController,
              'As senhas não conferem',
            ),
          ]),
          decoration: InputDecoration(
            labelText: 'Confirmar nova senha',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                );
              },
            ),
          ),
        ),

        _errorMessage(provider),

        const SizedBox(height: 24),

        _submitButton(provider, 'Alterar senha', _resetPassword),
      ],
    );
  }

  // ETAPA 4: sucesso, redireciona sozinho para o login
  Widget _successStep() {
    return SuccessView(
      title: 'Senha alterada!',
      message: 'Você será redirecionado para o login.',
      // go (e não pop): o fluxo acabou, o voltar não deve retornar para cá
      onDone: () => context.go('/login'),
    );
  }

  // título + texto de apoio de cada etapa
  Widget _header(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // mensagem de erro do provider (só aparece se houver)
  Widget _errorMessage(RecoveryProvider provider) {
    final error = provider.errorMessage;

    if (error == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        error,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  // botão principal da etapa: reage ao estado de loading
  Widget _submitButton(
    RecoveryProvider provider,
    String label,
    VoidCallback onPressed,
  ) {
    final loading = provider.isLoading;

    return FilledButton(
      // null desabilita o botão durante o loading
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
