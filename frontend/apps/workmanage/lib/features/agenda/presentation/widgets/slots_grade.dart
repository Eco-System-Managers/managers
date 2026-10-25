import 'package:flutter/material.dart';
import 'package:managers/core/utils/datas.dart';

import '../../domain/entities/slot.dart';

// a grade de horários de um dia: um chip por slot, os ocupados apagados
class SlotsGrade extends StatelessWidget {
  const SlotsGrade({
    super.key,
    required this.slots,
    required this.selecionada,
    required this.onSelecionar,
    this.carregando = false,
    this.erro,
    this.onTentarDeNovo,
  });

  final List<Slot> slots;
  final Hora? selecionada;
  final ValueChanged<Hora> onSelecionar;
  final bool carregando;
  final String? erro;
  final VoidCallback? onTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (carregando) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (erro != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(erro!, style: TextStyle(color: colors.error)),
          if (onTentarDeNovo != null)
            TextButton(
              onPressed: onTentarDeNovo,
              child: const Text('Tentar de novo'),
            ),
        ],
      );
    }
    if (slots.isEmpty) {
      return Text(
        'Sem horários neste dia: o negócio não abre ou o serviço não cabe '
        'no expediente.',
        style: TextStyle(color: colors.onSurfaceVariant),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final slot in slots)
          ChoiceChip(
            label: Text(formatarHora(slot.hora)),
            selected: slot.hora == selecionada,
            onSelected: slot.disponivel ? (_) => onSelecionar(slot.hora) : null,
          ),
      ],
    );
  }
}
