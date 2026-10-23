import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/widgets/auth_logo.dart';
import 'package:managers/core/widgets/auth_panel.dart';
import 'package:pinput/pinput.dart';
import 'package:validatorless/validatorless.dart';

import '../../register_injection.dart';
import '../view_models/verify_email_view_model.dart';

// depois do cadastro: a pessoa digita o código que chegou no e-mail.
// o e-mail vem pela rota (/register/verificar?email=...)
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  static const _codeLength = VerifyEmailViewModel.codeLength;

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(verifyEmailViewModelProvider)
        .confirm(email: widget.email, code: _codeController.text);

    if (!mounted) return;

    // código errado: limpa as caixinhas para digitar de novo
    if (!success) {
      _codeController.clear();
      return;
    }

    // go, não push: confirmado, não há por que voltar para cá
    context.go('/onboarding');
  }

  Future<void> _resend() async {
    _codeController.clear();
    await ref.read(verifyEmailViewModelProvider).resend(widget.email);
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o view model vivo enquanto a tela estiver aberta
    final viewModel = ref.watch(verifyEmailViewModelProvider);
    final colors = Theme.of(context).colorScheme;

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

    return Scaffold(
      backgroundColor: colors.primary,

      body: SafeArea(
        child: Column(
          children: [
            const Expanded(child: AuthLogo(showName: false)),

            AuthPanel(
              child: Form(
                key: _formKey,
                child: ListenableBuilder(
                  listenable: viewModel,
                  builder: (context, _) {
                    final loading = viewModel.isLoading;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Verifique seu e-mail',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Digite o código de $_codeLength dígitos enviado '
                          'para ${widget.email}.',
                          style: TextStyle(color: colors.onSurfaceVariant),
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
                              border: Border.all(
                                color: colors.primary,
                                width: 2,
                              ),
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
                            // ao digitar o último dígito, já confirma
                            onCompleted: (_) => _confirm(),
                          ),
                        ),

                        if (viewModel.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              viewModel.errorMessage!,
                              style: TextStyle(color: colors.error),
                            ),
                          ),

                        if (viewModel.infoMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              viewModel.infoMessage!,
                              style: TextStyle(color: colors.primary),
                            ),
                          ),

                        const SizedBox(height: 24),

                        FilledButton(
                          onPressed: loading ? null : _confirm,
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
                              : const Text('Confirmar'),
                        ),

                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // errou o e-mail: volta para o formulário
                            TextButton(
                              onPressed: loading
                                  ? null
                                  : () => context.go('/register'),
                              child: const Text('Trocar e-mail'),
                            ),
                            TextButton(
                              onPressed: loading || viewModel.secondsLeft > 0
                                  ? null
                                  : _resend,
                              child: Text(
                                viewModel.secondsLeft > 0
                                    ? 'Reenviar em ${viewModel.secondsLeft}s'
                                    : 'Reenviar código',
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
