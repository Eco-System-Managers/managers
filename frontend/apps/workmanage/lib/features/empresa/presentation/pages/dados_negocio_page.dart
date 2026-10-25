import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../empresa_provider.dart';
import '../widgets/dados_negocio_form.dart';

// edita nome, telefone, documento e endereço: o mesmo formulário do
// onboarding, abrindo preenchido com a config atual
class DadosNegocioPage extends ConsumerStatefulWidget {
  const DadosNegocioPage({super.key});

  @override
  ConsumerState<DadosNegocioPage> createState() => _DadosNegocioPageState();
}

class _DadosNegocioPageState extends ConsumerState<DadosNegocioPage> {
  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(dadosNegocioProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dados do negócio')),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          // salvou: avisa e fecha
          if (provider.salvo) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Dados salvos')));
              context.pop();
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (provider.errorMessage != null) ...[
                  _MensagemDeErro(mensagem: provider.errorMessage!),
                  const SizedBox(height: 16),
                ],
                DadosNegocioForm(
                  config: provider.config,
                  buscandoCep: provider.buscandoCep,
                  cepErro: provider.cepErrorMessage,
                  enabled: !provider.isLoading,
                  onBuscarCep: provider.buscarCep,
                  onSubmit: provider.salvar,
                  textoBotao: 'Salvar',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MensagemDeErro extends StatelessWidget {
  const _MensagemDeErro({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(mensagem, style: TextStyle(color: colors.onErrorContainer)),
    );
  }
}
