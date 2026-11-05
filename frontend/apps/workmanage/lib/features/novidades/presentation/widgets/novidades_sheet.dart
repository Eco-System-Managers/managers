import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/widgets/folha.dart';

import '../../domain/entities/novidade.dart';

// a folha de novidades: o que a versão trouxe, a principal primeiro, e a
// saída na hora. fecha com true quando a pessoa quer ver na agenda
class NovidadesSheet extends StatelessWidget {
  const NovidadesSheet({super.key, required this.itens});

  final List<Novidade> itens;

  static Future<bool?> abrir(BuildContext context, List<Novidade> itens) {
    return abrirFolha<bool>(
      context,
      builder: (_) => NovidadesSheet(itens: itens),
    );
  }

  static IconData _icone(TipoDeNovidade tipo) => switch (tipo) {
    TipoDeNovidade.variosServicos => Icons.playlist_add_check_rounded,
    TipoDeNovidade.tema => Icons.dark_mode_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final levaParaAgenda = itens.any(
      (n) => n.tipo == TipoDeNovidade.variosServicos,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(BrandSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Novidades desta versão', style: textos.titleLarge),
          const SizedBox(height: BrandSpacing.space5),
          for (final n in itens) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(BrandSpacing.space2),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BrandRadius.mdAll,
                  ),
                  child: Icon(
                    _icone(n.tipo),
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: BrandSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.titulo, style: textos.titleSmall),
                      const SizedBox(height: BrandSpacing.space1),
                      Text(
                        n.texto,
                        style: textos.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: BrandSpacing.space4),
          ],
          const SizedBox(height: BrandSpacing.space2),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(levaParaAgenda),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(levaParaAgenda ? 'Ver na agenda' : 'Entendi'),
          ),
          if (levaParaAgenda) ...[
            const SizedBox(height: BrandSpacing.space2),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Entendi'),
            ),
          ],
        ],
      ),
    );
  }
}
