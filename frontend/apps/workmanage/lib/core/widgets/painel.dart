import 'package:flutter/material.dart';

// o cartão neutro das seções do Início e do Caixa: superfície com borda
// fina, sem cor de fundo. a cor fica para o que é destaque de verdade
class Painel extends StatelessWidget {
  const Painel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}

// o título de uma seção, com um detalhe discreto ao lado ("6 horários")
class TituloDaSecao extends StatelessWidget {
  const TituloDaSecao(this.titulo, {super.key, this.detalhe});

  final String titulo;
  final String? detalhe;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          titulo,
          style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (detalhe != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detalhe!,
              style: textos.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
