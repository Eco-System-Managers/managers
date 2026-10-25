import 'package:flutter/material.dart';

import '../../domain/entities/agendamento.dart';

// como cada status aparece: nome, ícone e cor
extension StatusAgendamentoVisual on StatusAgendamento {
  String get nome => switch (this) {
    StatusAgendamento.agendado => 'Agendado',
    StatusAgendamento.confirmado => 'Confirmado',
    StatusAgendamento.concluido => 'Concluído',
    StatusAgendamento.cancelado => 'Cancelado',
    StatusAgendamento.faltou => 'Faltou',
  };

  IconData get icone => switch (this) {
    StatusAgendamento.agendado => Icons.schedule,
    StatusAgendamento.confirmado => Icons.thumb_up_alt_outlined,
    StatusAgendamento.concluido => Icons.check_circle_outline,
    StatusAgendamento.cancelado => Icons.cancel_outlined,
    StatusAgendamento.faltou => Icons.person_off_outlined,
  };

  Color cor(ColorScheme colors) => switch (this) {
    StatusAgendamento.agendado => colors.primary,
    StatusAgendamento.confirmado => colors.tertiary,
    StatusAgendamento.concluido => Colors.green.shade700,
    StatusAgendamento.cancelado => colors.outline,
    StatusAgendamento.faltou => colors.error,
  };
}

class StatusAgendamentoChip extends StatelessWidget {
  const StatusAgendamentoChip({super.key, required this.status});

  final StatusAgendamento status;

  @override
  Widget build(BuildContext context) {
    final cor = status.cor(Theme.of(context).colorScheme);
    return Chip(
      avatar: Icon(status.icone, size: 16, color: cor),
      label: Text(status.nome),
      labelStyle: TextStyle(color: cor, fontSize: 12),
      side: BorderSide(color: cor.withValues(alpha: 0.5)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
