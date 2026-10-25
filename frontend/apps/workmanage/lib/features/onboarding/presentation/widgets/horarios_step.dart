import 'package:flutter/material.dart';
import 'package:managers/features/empresa/presentation/widgets/horario_dia_card.dart';

import '../providers/wizard_provider.dart';

// step 3: os dias e horários de trabalho, com os mesmos cards das
// configurações. para agenda kanban, cada dia aberto pede também a
// capacidade (quantos atendimentos o negócio dá conta no dia)
class HorariosStep extends StatelessWidget {
  const HorariosStep({super.key, required this.provider});

  final WizardProvider provider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          provider.isKanban
              ? 'Marque os dias abertos, o horário e quantos atendimentos '
                    'cabem em cada dia.'
              : 'Marque os dias abertos e o horário de cada um.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 16),

        for (final horario in provider.horarios) ...[
          HorarioDiaCard(
            horario: horario,
            isKanban: provider.isKanban,
            erro: provider.erroDoHorario(horario),
            enabled: !provider.isLoading,
            onChanged: provider.atualizarHorario,
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 12),

        FilledButton(
          onPressed: provider.isLoading ? null : provider.concluir,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Concluir'),
        ),
      ],
    );
  }
}
