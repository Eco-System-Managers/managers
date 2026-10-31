import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/features/empresa/presentation/widgets/horario_dia_card.dart';

import '../providers/wizard_provider.dart';

// step 3: os dias e horários de trabalho, com os mesmos cards das
// configurações. na esteira, cada dia aberto tem também os próprios números:
// o máximo no dia e o ao mesmo tempo
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
              ? 'Marque os dias abertos, o horário e quanto cabe em cada dia.'
              : 'Marque os dias abertos e o horário de cada um.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: BrandColors.of(context).inkMuted),
        ),

        const SizedBox(height: BrandSpacing.space3),

        // acerta o primeiro dia e copia para os outros
        RepetirDiaButton(
          primeiroDiaAberto: provider.primeiroDiaAberto,
          enabled: !provider.isLoading,
          onPressed: provider.repetirPrimeiroDiaNosOutros,
        ),

        const SizedBox(height: BrandSpacing.space4),

        for (final horario in provider.horarios) ...[
          HorarioDiaCard(
            horario: horario,
            isKanban: provider.isKanban,
            erro: provider.erroDoHorario(horario),
            enabled: !provider.isLoading,
            onChanged: provider.atualizarHorario,
          ),
          const SizedBox(height: BrandSpacing.space3),
        ],

        if (provider.isKanban) ...[
          const AjudaDosNumeros(),
          const SizedBox(height: BrandSpacing.space3),
        ],

        const SizedBox(height: BrandSpacing.space3),

        FilledButton(
          onPressed: provider.isLoading ? null : provider.concluir,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Concluir'),
        ),
      ],
    );
  }
}
