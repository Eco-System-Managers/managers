import 'package:flutter/material.dart';

import '../../domain/entities/contrato.dart';

// o status do contrato como chip: a cor diz o que falta fazer
class StatusContratoChip extends StatelessWidget {
  const StatusContratoChip({super.key, required this.status});

  final StatusContrato status;

  static Color cor(StatusContrato status, ColorScheme colors) {
    return switch (status) {
      StatusContrato.pendente => colors.onSurfaceVariant,
      StatusContrato.enviado => colors.primary,
      StatusContrato.assinado => Colors.green.shade700,
      StatusContrato.recusado => colors.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final corDoStatus = cor(status, colors);

    return Chip(
      label: Text(status.nome),
      labelStyle: TextStyle(color: corDoStatus, fontSize: 12),
      side: BorderSide(color: corDoStatus.withValues(alpha: 0.5)),
      backgroundColor: Colors.transparent,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
