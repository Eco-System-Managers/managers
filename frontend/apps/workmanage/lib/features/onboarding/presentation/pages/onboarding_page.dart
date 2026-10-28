import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/success_view.dart';

import '../../onboarding_provider.dart';
import '../providers/wizard_provider.dart';
import '../widgets/horarios_step.dart';
import '../widgets/negocio_step.dart';
import '../widgets/nicho_step.dart';

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
                    icon: const Icon(Icons.arrow_back_rounded),
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
        return EstadoErro(
          mensagem: wizard.errorMessage!,
          onTentarDeNovo: wizard.carregar,
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (wizard.step == WizardStep.concluido) {
      return Padding(
        padding: const EdgeInsets.all(BrandSpacing.space5),
        child: Center(
          child: SuccessView(
            title: 'Tudo pronto',
            message: 'Seu negócio está configurado.',
            // a sessão já existe desde o cadastro: o fim do wizard é a home.
            // go, não push: o onboarding não fica no histórico do "voltar"
            onDone: () => context.go('/home'),
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
            padding: const EdgeInsets.all(BrandSpacing.space5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Etapa ${wizard.step.index + 1} de $_totalEtapas',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: BrandSpacing.space1),
                // o título da etapa é um título de seção: h3
                Text(
                  _titulo(wizard.step),
                  style: Theme.of(context).textTheme.titleLarge,
                ),

                const SizedBox(height: BrandSpacing.space5),

                // erro da última ação (salvar, concluir...)
                if (wizard.errorMessage != null) ...[
                  _MensagemDeErro(mensagem: wizard.errorMessage!),
                  const SizedBox(height: BrandSpacing.space4),
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
      WizardStep.nicho => NichoStep(provider: wizard),
      WizardStep.horarios => HorariosStep(provider: wizard),
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
