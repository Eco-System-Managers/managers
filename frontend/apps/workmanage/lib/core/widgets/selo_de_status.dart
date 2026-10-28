import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';

// um status como selo (ativo, inativo, convite enviado, pendente...): a cor
// do status vai no texto e no ícone, sobre fundo neutro com borda fina.
// success para concluído ou aprovado, warning para pendente, danger para
// erro ou recusa; os neutros vão em inkMuted ou ink
class SeloDeStatus extends StatelessWidget {
  const SeloDeStatus({
    super.key,
    required this.texto,
    required this.cor,
    this.icone,
  });

  final String texto;
  final Color cor;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    return Chip(
      avatar: icone == null ? null : Icon(icone, size: 16, color: cor),
      label: Text(texto),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(color: cor),
      backgroundColor: Colors.transparent,
      side: BorderSide(color: cores.border),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
