import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/grade_de_horarios.dart';

import '../../domain/entities/slot.dart';

// a grade de horários de um dia na agenda: carregando, erro e dia sem
// horário livre em volta da GradeDeHorarios do core (a API da agenda só
// manda os livres, de 15 em 15 min mais o fim de cada agendamento)
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

    // a API da agenda só manda os livres; um ocupado, se vier, fica apagado
    final livres = {
      for (final s in slots)
        if (s.disponivel) s.hora,
    };
    return GradeDeHorarios(
      horas: [for (final s in slots) s.hora],
      selecionada: selecionada,
      onSelecionar: onSelecionar,
      disponivel: livres.contains,
    );
  }
}
