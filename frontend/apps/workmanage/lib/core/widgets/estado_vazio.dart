import 'package:flutter/material.dart';

// o estado "ainda não tem nada" de uma lista: texto curto e, quando faz
// sentido, a ação que cria o primeiro item
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    this.mensagem,
    this.acao,
  });

  final IconData icone;
  final String titulo;
  final String? mensagem;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 56, color: colors.outline),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (mensagem != null) ...[
              const SizedBox(height: 8),
              Text(
                mensagem!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
            if (acao != null) ...[const SizedBox(height: 24), acao!],
          ],
        ),
      ),
    );
  }
}
