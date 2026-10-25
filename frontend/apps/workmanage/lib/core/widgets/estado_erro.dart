import 'package:flutter/material.dart';

// o estado de erro de uma tela: o detail que a API mandou e o botão de
// tentar de novo
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
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: colors.error),
            const SizedBox(height: 16),
            Text(mensagem, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: onTentarDeNovo,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
