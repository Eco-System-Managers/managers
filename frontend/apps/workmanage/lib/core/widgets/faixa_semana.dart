import 'package:flutter/material.dart';
import 'package:managers/core/utils/datas.dart';

// os sete dias da semana do dia escolhido (agenda e quadro), de segunda a domingo, com uma
// bolinha nos que têm agendamento. as setas andam uma semana
class FaixaSemana extends StatelessWidget {
  const FaixaSemana({
    super.key,
    required this.dia,
    required this.hoje,
    required this.temRegistro,
    required this.onSelecionar,
  });

  final DateTime dia;
  final DateTime hoje;
  final bool Function(DateTime data) temRegistro;
  final ValueChanged<DateTime> onSelecionar;

  // a semana (segunda a domingo) que contém o dia
  static List<DateTime> diasDaSemana(DateTime dia) {
    final segunda = DateTime(dia.year, dia.month, dia.day - (dia.weekday - 1));
    return [
      for (var i = 0; i < 7; i++)
        DateTime(segunda.year, segunda.month, segunda.day + i),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dias = diasDaSemana(dia);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Semana anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                onSelecionar(DateTime(dia.year, dia.month, dia.day - 7)),
          ),
          for (final d in dias)
            Expanded(
              child: _Dia(
                data: d,
                selecionado: mesmoDia(d, dia),
                ehHoje: mesmoDia(d, hoje),
                marcado: temRegistro(d),
                onTap: () => onSelecionar(d),
              ),
            ),
          IconButton(
            tooltip: 'Próxima semana',
            icon: const Icon(Icons.chevron_right),
            onPressed: () =>
                onSelecionar(DateTime(dia.year, dia.month, dia.day + 7)),
          ),
        ],
      ),
    );
  }
}

class _Dia extends StatelessWidget {
  const _Dia({
    required this.data,
    required this.selecionado,
    required this.ehHoje,
    required this.marcado,
    required this.onTap,
  });

  final DateTime data;
  final bool selecionado;
  final bool ehHoje;
  final bool marcado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final corTexto = selecionado
        ? colors.onPrimary
        : ehHoje
        ? colors.primary
        : colors.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selecionado ? colors.primary : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              nomeCurtoDoDia(data),
              style: TextStyle(fontSize: 11, color: corTexto),
            ),
            const SizedBox(height: 2),
            Text(
              '${data.day}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: selecionado || ehHoje
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: corTexto,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: marcado
                    ? (selecionado ? colors.onPrimary : colors.primary)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
