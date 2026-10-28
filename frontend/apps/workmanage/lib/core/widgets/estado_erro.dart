import 'package:flutter/material.dart';

import '../theme/brand.dart';

// o estado de erro de uma tela: o detail que a API mandou e o botão de
// tentar de novo, que é a ação principal
class EstadoErro extends StatelessWidget {
  const EstadoErro({
    super.key,
    required this.mensagem,
    required this.onTentarDeNovo,
  });

  final String mensagem;
  final VoidCallback onTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BrandSpacing.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: cores.danger),
            const SizedBox(height: BrandSpacing.space4),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: textos.titleMedium,
            ),
            const SizedBox(height: BrandSpacing.space5),
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
