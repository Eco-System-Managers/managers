import 'package:flutter/material.dart';

import '../../domain/entities/horario_funcionamento.dart';
import '../providers/wizard_provider.dart';

// step 3: os dias e horários de trabalho. para agenda kanban, cada dia aberto
// pede também a capacidade (quantos atendimentos o negócio dá conta no dia)
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
          _DiaCard(
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

class _DiaCard extends StatelessWidget {
  const _DiaCard({
    required this.horario,
    required this.isKanban,
    required this.erro,
    required this.enabled,
    required this.onChanged,
  });

  final HorarioFuncionamento horario;
  final bool isKanban;
  final String? erro;
  final bool enabled;
  final ValueChanged<HorarioFuncionamento> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // nome do dia + aberto/fechado
            Row(
              children: [
                Expanded(
                  child: Text(
                    _nomeDoDia(horario.dia),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  horario.ativo ? 'Aberto' : 'Fechado',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                Switch(
                  value: horario.ativo,
                  onChanged: enabled
                      ? (ativo) => onChanged(horario.copyWith(ativo: ativo))
                      : null,
                ),
              ],
            ),

            if (horario.ativo) ...[
              Row(
                children: [
                  Expanded(
                    child: _HoraButton(
                      rotulo: 'Abre',
                      hora: horario.abertura,
                      enabled: enabled,
                      onChanged: (hora) =>
                          onChanged(horario.copyWith(abertura: hora)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HoraButton(
                      rotulo: 'Fecha',
                      hora: horario.fechamento,
                      enabled: enabled,
                      onChanged: (hora) =>
                          onChanged(horario.copyWith(fechamento: hora)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              if (isKanban)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _Capacidade(
                    valor: horario.capacidade,
                    enabled: enabled,
                    onChanged: (capacidade) =>
                        onChanged(horario.copyWith(capacidade: capacidade)),
                  ),
                ),
            ],

            if (erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(erro!, style: TextStyle(color: colors.error)),
              ),
          ],
        ),
      ),
    );
  }

  String _nomeDoDia(DiaSemana dia) {
    return switch (dia) {
      DiaSemana.segunda => 'Segunda-feira',
      DiaSemana.terca => 'Terça-feira',
      DiaSemana.quarta => 'Quarta-feira',
      DiaSemana.quinta => 'Quinta-feira',
      DiaSemana.sexta => 'Sexta-feira',
      DiaSemana.sabado => 'Sábado',
      DiaSemana.domingo => 'Domingo',
    };
  }
}

// botão que mostra a hora e abre o relógio do sistema para trocar
class _HoraButton extends StatelessWidget {
  const _HoraButton({
    required this.rotulo,
    required this.hora,
    required this.enabled,
    required this.onChanged,
  });

  final String rotulo;
  final HoraDoDia? hora;
  final bool enabled;
  final ValueChanged<HoraDoDia> onChanged;

  Future<void> _escolher(BuildContext context) async {
    final atual = hora ?? const HoraDoDia(8, 0);
    // o TimeOfDay é do Flutter: a conversão para HoraDoDia fica aqui, na
    // presentation, e o domain continua sem saber de Flutter
    final escolhida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: atual.hora, minute: atual.minuto),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (escolhida != null) {
      onChanged(HoraDoDia(escolhida.hour, escolhida.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = hora == null
        ? '--:--'
        : '${hora!.hora.toString().padLeft(2, '0')}:'
              '${hora!.minuto.toString().padLeft(2, '0')}';

    return OutlinedButton.icon(
      onPressed: enabled ? () => _escolher(context) : null,
      icon: const Icon(Icons.schedule, size: 18),
      label: Text('$rotulo $texto'),
    );
  }
}

// contador de atendimentos por dia: menos, número e mais
class _Capacidade extends StatelessWidget {
  const _Capacidade({
    required this.valor,
    required this.enabled,
    required this.onChanged,
  });

  final int? valor;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final atual = valor ?? 0;

    return Row(
      children: [
        const Expanded(child: Text('Atendimentos no dia')),
        IconButton(
          onPressed: enabled && atual > 1 ? () => onChanged(atual - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 32,
          child: Text(
            atual == 0 ? '-' : '$atual',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          onPressed: enabled ? () => onChanged(atual + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
