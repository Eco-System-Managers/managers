import 'package:flutter/material.dart';

import '../theme/brand.dart';

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
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BrandSpacing.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // o ícone é neutro: a borda sumiria sobre o fundo
            Icon(icone, size: 56, color: cores.inkMuted),
            const SizedBox(height: BrandSpacing.space4),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: textos.titleMedium,
            ),
            if (mensagem != null) ...[
              const SizedBox(height: BrandSpacing.space2),
              Text(
                mensagem!,
                textAlign: TextAlign.center,
                style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
              ),
            ],
            if (acao != null) ...[
              const SizedBox(height: BrandSpacing.space5),
              acao!,
            ],
          ],
        ),
      ),
    );
  }
}
