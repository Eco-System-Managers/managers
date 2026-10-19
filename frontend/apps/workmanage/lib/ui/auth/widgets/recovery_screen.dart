import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/ui/auth/view_models/recovery_view_model.dart';
import 'package:managers/ui/core/ui/success_view.dart';
import 'package:pinput/pinput.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key, required this.viewModel});

  // a tela recebe o viewmodel de fora (vem do app_router.dart)
  final RecoveryViewModel viewModel;

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
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

  // libera a memória dos controllers quando a tela é destruída
  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // cada ação valida o form e entrega o valor para o viewmodel.
  // a troca de etapa é decidida lá: a tela só redesenha pelo ListenableBuilder
  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.viewModel.sendCode(_emailController.text);
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.viewModel.verifyCode(_codeController.text);
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.viewModel.resetPassword(_passwordController.text);
  }

  Future<void> _resendCode() async {
    // o código antigo não vale mais
    _codeController.clear();
    await widget.viewModel.resendCode();
  }

  void _changeEmail() {
    _codeController.clear();
    widget.viewModel.backToEmail();
  }

  @override
  Widget build(BuildContext context) {
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
            const Expanded(child: SizedBox()),
            // painel inferior arredondado, igual ao do login
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Form(
                key: _formKey,
                // redesenha o painel sempre que o viewmodel avisar
                // (troca de etapa, loading ou erro)
                child: ListenableBuilder(
                  listenable: widget.viewModel,
                  builder: (context, _) {
                    // mostra só a etapa atual
                    return switch (widget.viewModel.step) {
                      RecoveryStep.email => _emailStep(),
                      RecoveryStep.code => _codeStep(),
                      RecoveryStep.newPassword => _newPasswordStep(),
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
  Widget _emailStep() {
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
          validator: widget.viewModel.validateEmail,
          decoration: const InputDecoration(
            labelText: 'E-mail',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
        ),

        _errorMessage(),

        const SizedBox(height: 24),

        _submitButton('Enviar código', _sendCode),
      ],
    );
  }

  // ETAPA 2: código de verificação
  Widget _codeStep() {
    final colors = Theme.of(context).colorScheme;
    final loading = widget.viewModel.isLoading;

    // aparência de cada caixinha do código
    final pinTheme = PinTheme(
      width: 44,
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
          'Digite o código de ${RecoveryViewModel.codeLength} dígitos '
              'enviado para ${widget.viewModel.email}.',
        ),

        const SizedBox(height: 24),

        Pinput(
          length: RecoveryViewModel.codeLength,
          controller: _codeController,
          autofocus: true,
          enabled: !loading,
          defaultPinTheme: pinTheme,
          // caixinha em foco ganha a cor da marca
          focusedPinTheme: pinTheme.copyBorderWith(
            border: Border.all(color: colors.primary, width: 2),
          ),
          separatorBuilder: (_) => const SizedBox(width: 8),
          validator: widget.viewModel.validateCode,
          // ao digitar o último dígito, já verifica
          onCompleted: (_) => _verifyCode(),
        ),

        _errorMessage(),

        const SizedBox(height: 24),

        _submitButton('Verificar', _verifyCode),

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
  Widget _newPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header('Nova senha', 'Crie uma nova senha para acessar sua conta.'),

        const SizedBox(height: 24),

        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          validator: widget.viewModel.validatePassword,
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
          validator: (value) => widget.viewModel.validateConfirmPassword(
            value,
            _passwordController.text,
          ),
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

        _errorMessage(),

        const SizedBox(height: 24),

        _submitButton('Alterar senha', _resetPassword),
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

  // mensagem de erro do viewmodel (só aparece se houver)
  Widget _errorMessage() {
    final error = widget.viewModel.errorMessage;

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
  Widget _submitButton(String label, VoidCallback onPressed) {
    final loading = widget.viewModel.isLoading;

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
