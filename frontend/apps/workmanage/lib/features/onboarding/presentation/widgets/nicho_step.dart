import 'package:flutter/material.dart';

import '../../domain/entities/nicho.dart';
import '../providers/wizard_provider.dart';
import 'nicho_visual.dart';

// step 2: escolher o ramo do negócio. tocar num card só marca; quem salva
// é o "Próximo" (o nicho decide o tipo de agenda no backend)
class NichoStep extends StatelessWidget {
  const NichoStep({super.key, required this.provider});

  final WizardProvider provider;

  @override
  Widget build(BuildContext context) {
    final selecionado = provider.config.nicho;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Escolha o que melhor descreve o seu negócio.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 16),

        // 3 colunas no celular, 4 no tablet
        LayoutBuilder(
          builder: (context, constraints) {
            final colunas = constraints.maxWidth >= 560 ? 4 : 3;

            return GridView.count(
              crossAxisCount: colunas,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
              // a rolagem é da página: a grade só ocupa a altura dela
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final nicho in Nicho.values)
                  _NichoCard(
                    nicho: nicho,
                    selecionado: nicho == selecionado,
                    onTap: provider.isLoading
                        ? null
                        : () => provider.escolherNicho(nicho),
                  ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        FilledButton(
          // sem nicho escolhido não há o que salvar
          onPressed: provider.isLoading || selecionado == null
              ? null
              : provider.salvarNicho,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Próximo'),
        ),
      ],
    );
  }
}

class _NichoCard extends StatelessWidget {
  const _NichoCard({
    required this.nicho,
    required this.selecionado,
    required this.onTap,
  });

  final Nicho nicho;
  final bool selecionado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final corConteudo = selecionado
        ? colors.onPrimaryContainer
        : colors.onSurface;

    return Material(
      color: selecionado ? colors.primaryContainer : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selecionado ? colors.primary : colors.outlineVariant,
          width: selecionado ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(nicho.icone, size: 32, color: corConteudo),
              const SizedBox(height: 8),
              Text(
                nicho.nome,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: corConteudo,
                  fontWeight: selecionado ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
