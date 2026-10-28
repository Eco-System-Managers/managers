import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';

import '../../domain/entities/slot.dart';

// a grade de horários de um dia: um chip por slot (a API da agenda só manda
// os livres, de 15 em 15 min mais o fim de cada agendamento; um ocupado,
// se vier, fica apagado)
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
    final textos = Theme.of(context).textTheme;

    if (carregando) {
      return const Padding(
        padding: EdgeInsets.all(BrandSpacing.space4),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (erro != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(erro!, style: textos.bodyMedium?.copyWith(color: colors.error)),
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
        'Sem horários livres neste dia. Escolha outro dia.',
        style: textos.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
      );
    }

    return Wrap(
      spacing: BrandSpacing.space2,
      runSpacing: BrandSpacing.space2,
      children: [
        for (final slot in slots)
          _ChipDoSlot(
            slot: slot,
            selecionado: slot.hora == selecionada,
            onSelecionar: onSelecionar,
          ),
      ],
    );
  }
}

// um slot: o escolhido é o azul da marca com texto branco, o livre é neutro
// com borda e o ocupado fica apagado no fundo 2
class _ChipDoSlot extends StatelessWidget {
  const _ChipDoSlot({
    required this.slot,
    required this.selecionado,
    required this.onSelecionar,
  });

  final Slot slot;
  final bool selecionado;
  final ValueChanged<Hora> onSelecionar;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final corDoTexto = selecionado
        ? cores.onBrand
        : slot.disponivel
        ? cores.ink
        : cores.inkMuted;

    return ChoiceChip(
      label: Text(formatarHora(slot.hora)),
      selected: selecionado,
      onSelected: slot.disponivel ? (_) => onSelecionar(slot.hora) : null,
      showCheckmark: false,
      selectedColor: BrandColors.brandBlue,
      side: BorderSide(
        color: selecionado ? BrandColors.brandBlue : cores.border,
      ),
      labelStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: corDoTexto),
    );
  }
}
