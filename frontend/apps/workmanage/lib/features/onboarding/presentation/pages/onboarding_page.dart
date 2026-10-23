import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/widgets/success_view.dart';

import '../../onboarding_provider.dart';
import '../providers/wizard_provider.dart';
import '../widgets/negocio_step.dart';

// o wizard do onboarding. a tela lê o provider pelo ref (como a register),
// e não recebe de fora: assim o router só faz const OnboardingPage()
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  // as etapas que contam no "Etapa x de 3"
  static const _totalEtapas = 3;

  @override
  void initState() {
    super.initState();
    // depois do primeiro build: o watch já está segurando o provider vivo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wizardProvider).carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final wizard = ref.watch(wizardProvider);

    return ListenableBuilder(
      listenable: wizard,
      builder: (context, _) {
        final podeVoltar =
            wizard.step == WizardStep.nicho ||
            wizard.step == WizardStep.horarios;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Configure seu negócio'),
            // sem a seta do sistema: voltar aqui é voltar uma etapa
            automaticallyImplyLeading: false,
            leading: podeVoltar
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: wizard.isLoading ? null : wizard.voltar,
                  )
                : null,
          ),
          body: SafeArea(child: _conteudo(context, wizard)),
        );
      },
    );
  }

  Widget _conteudo(BuildContext context, WizardProvider wizard) {
    // primeira carga: ainda não sabe em que etapa abrir
    if (!wizard.carregado) {
      if (wizard.errorMessage != null) {
        return _ErroAoCarregar(
          mensagem: wizard.errorMessage!,
          onTentarDeNovo: wizard.carregar,
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (wizard.step == WizardStep.concluido) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SuccessView(
            title: 'Tudo pronto!',
            message: 'Seu negócio está configurado.',
            // TODO: ir para a home quando ela existir
            onDone: () => context.go('/login'),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // progresso: a barra fina mostra também o loading das ações
        LinearProgressIndicator(
          value: wizard.isLoading
              ? null
              : (wizard.step.index + 1) / _totalEtapas,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Etapa ${wizard.step.index + 1} de $_totalEtapas',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  _titulo(wizard.step),
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 24),

                // erro da última ação (salvar, concluir...)
                if (wizard.errorMessage != null) ...[
                  _MensagemDeErro(mensagem: wizard.errorMessage!),
                  const SizedBox(height: 16),
                ],

                // troca de etapa com um fade, sem precisar de PageView
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(wizard.step),
                    child: _etapa(wizard),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _titulo(WizardStep step) {
    return switch (step) {
      WizardStep.negocio => 'Dados do negócio',
      WizardStep.nicho => 'Ramo do negócio',
      WizardStep.horarios => 'Dias e horários',
      WizardStep.concluido => '',
    };
  }

  Widget _etapa(WizardProvider wizard) {
    return switch (wizard.step) {
      WizardStep.negocio => NegocioStep(provider: wizard),
      // TODO: trocar pelos steps 2 e 3
      WizardStep.nicho || WizardStep.horarios => const _EmConstrucao(),
      WizardStep.concluido => const SizedBox.shrink(),
    };
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

class _ErroAoCarregar extends StatelessWidget {
  const _ErroAoCarregar({required this.mensagem, required this.onTentarDeNovo});

  final String mensagem;
  final VoidCallback onTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mensagem, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onTentarDeNovo,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

// provisório: ocupa o lugar dos steps 2 e 3 até eles existirem
class _EmConstrucao extends StatelessWidget {
  const _EmConstrucao();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Text('Em construção', textAlign: TextAlign.center),
    );
  }
}
