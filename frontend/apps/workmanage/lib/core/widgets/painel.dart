import 'package:flutter/material.dart';

import '../theme/brand.dart';

// o cartão neutro das seções do Início e do Caixa: o fundo da página com a
// borda fina, sem sombra. a cor fica para o que é destaque de verdade
class Painel extends StatelessWidget {
  const Painel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    return Container(
      padding: padding ?? const EdgeInsets.all(BrandSpacing.space4),
      decoration: BoxDecoration(
        color: cores.bg,
        borderRadius: BrandRadius.mdAll,
        border: Border.all(color: cores.border),
      ),
      child: child,
    );
  }
}

// o título de uma seção (h3), com um detalhe discreto ao lado ("6 horários")
class TituloDaSecao extends StatelessWidget {
  const TituloDaSecao(this.titulo, {super.key, this.detalhe});

  final String titulo;
  final String? detalhe;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(titulo, style: textos.titleLarge),
        if (detalhe != null) ...[
          const SizedBox(width: BrandSpacing.space2),
          Expanded(
            child: Text(
              detalhe!,
              style: textos.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
