import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:validatorless/validatorless.dart';

import '../../usuarios_provider.dart';

// convida alguém para a equipe: a API manda o e-mail com o link para a
// pessoa definir a senha. fecha com true quando criou
class ConviteFormPage extends ConsumerStatefulWidget {
  const ConviteFormPage({super.key});

  @override
  ConsumerState<ConviteFormPage> createState() => _ConviteFormPageState();
}

class _ConviteFormPageState extends ConsumerState<ConviteFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(conviteFormProvider)
        .salvar(nome: _nomeController.text, email: _emailController.text);
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(conviteFormProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Convidar para a equipe')),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          if (provider.salvo) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.pop(true);
            });
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'A pessoa recebe um e-mail com o link para criar a senha e '
                  'entrar. O convite vale por 2 dias.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 24),

                if (provider.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      provider.errorMessage!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _nomeController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  forceErrorText: provider.erroDoCampo('nome'),
                  onChanged: (_) => provider.limparErroDoCampo('nome'),
                  decoration: const InputDecoration(
                    labelText: 'Nome (opcional)',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _enviar(),
                  validator: Validatorless.multiple([
                    Validatorless.required('Informe o e-mail'),
                    Validatorless.email('E-mail inválido'),
                  ]),
                  forceErrorText: provider.erroDoCampo('email'),
                  onChanged: (_) => provider.limparErroDoCampo('email'),
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.mail_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: provider.isLoading ? null : _enviar,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Enviar convite'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
