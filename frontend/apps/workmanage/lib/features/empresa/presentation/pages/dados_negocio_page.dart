import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/widgets/folha.dart';

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
            padding: paddingDaPagina(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (provider.errorMessage != null) ...[
                  _MensagemDeErro(mensagem: provider.errorMessage!),
                  const SizedBox(height: BrandSpacing.space4),
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
    final textos = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(BrandSpacing.space3),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BrandRadius.mdAll,
      ),
      child: Text(
        mensagem,
        style: textos.bodyMedium?.copyWith(color: colors.onErrorContainer),
      ),
    );
  }
}
