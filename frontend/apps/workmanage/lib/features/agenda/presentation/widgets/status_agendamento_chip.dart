import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';

import '../../domain/entities/agendamento.dart';

// como cada status aparece: nome, ícone e cor. a cor vai no texto e no
// ícone; agendado e cancelado são neutros
extension StatusAgendamentoVisual on StatusAgendamento {
  String get nome => switch (this) {
    StatusAgendamento.agendado => 'Agendado',
    StatusAgendamento.confirmado => 'Confirmado',
    StatusAgendamento.concluido => 'Concluído',
    StatusAgendamento.cancelado => 'Cancelado',
    StatusAgendamento.faltou => 'Faltou',
  };

  IconData get icone => switch (this) {
    StatusAgendamento.agendado => Icons.schedule_rounded,
    StatusAgendamento.confirmado => Icons.thumb_up_alt_rounded,
    StatusAgendamento.concluido => Icons.check_circle_outline_rounded,
    StatusAgendamento.cancelado => Icons.cancel_rounded,
    StatusAgendamento.faltou => Icons.person_off_rounded,
  };

  Color cor(BrandColors cores) => switch (this) {
    StatusAgendamento.agendado => cores.inkMuted,
    StatusAgendamento.confirmado => cores.ink,
    StatusAgendamento.concluido => cores.success,
    StatusAgendamento.cancelado => cores.inkMuted,
    StatusAgendamento.faltou => cores.danger,
  };
}

class StatusAgendamentoChip extends StatelessWidget {
  const StatusAgendamentoChip({super.key, required this.status});

  final StatusAgendamento status;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final cor = status.cor(cores);
    return Chip(
      avatar: Icon(status.icone, size: 16, color: cor),
      label: Text(status.nome),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(color: cor),
      backgroundColor: Colors.transparent,
      side: BorderSide(color: cores.border),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
