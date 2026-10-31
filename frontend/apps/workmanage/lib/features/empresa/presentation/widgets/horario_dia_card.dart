import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';

import '../../domain/entities/horario_funcionamento.dart';

// um dia da semana: aberto ou fechado, abre e fecha a que horas e, na
// esteira, quanto cabe nele: o máximo no dia e o ao mesmo tempo. o mesmo
// card no onboarding e nas configurações; no modo agenda só as horas
class HorarioDiaCard extends StatelessWidget {
  const HorarioDiaCard({
    super.key,
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
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BrandSpacing.space4,
          BrandSpacing.space2,
          BrandSpacing.space2,
          BrandSpacing.space3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // nome do dia + aberto/fechado
            Row(
              children: [
                Expanded(
                  child: Text(nomeDoDia(horario.dia), style: textos.titleSmall),
                ),
                Text(
                  horario.ativo ? 'Aberto' : 'Fechado',
                  style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
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
                  const SizedBox(width: BrandSpacing.space2),
                  Expanded(
                    child: _HoraButton(
                      rotulo: 'Fecha',
                      hora: horario.fechamento,
                      enabled: enabled,
                      onChanged: (hora) =>
                          onChanged(horario.copyWith(fechamento: hora)),
                    ),
                  ),
                  const SizedBox(width: BrandSpacing.space2),
                ],
              ),

              if (isKanban) ...[
                Padding(
                  padding: const EdgeInsets.only(top: BrandSpacing.space2),
                  child: _MaximoNoDia(
                    valor: horario.capacidade,
                    enabled: enabled,
                    onChanged: (capacidade) =>
                        onChanged(horario.copyWith(capacidade: capacidade)),
                  ),
                ),
                _Contador(
                  rotulo: 'Ao mesmo tempo',
                  valor: horario.vagas,
                  enabled: enabled,
                  onChanged: (vagas) =>
                      onChanged(horario.copyWith(vagas: vagas)),
                ),
              ],
            ],

            if (erro != null)
              Padding(
                padding: const EdgeInsets.only(top: BrandSpacing.space2),
                child: Text(
                  erro!,
                  style: textos.bodySmall?.copyWith(color: colors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String nomeDoDia(DiaSemana dia) {
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
      icon: const Icon(Icons.schedule_rounded, size: 18),
      label: Text('$rotulo $texto'),
    );
  }
}

// o máximo de atendimentos no dia. null é sem máximo: o dia conta todos,
// com ou sem hora, e nunca enche. o chip tira o máximo; o mais traz de volta
class _MaximoNoDia extends StatelessWidget {
  const _MaximoNoDia({
    required this.valor,
    required this.enabled,
    required this.onChanged,
  });

  final int? valor;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final atual = valor;

    return Row(
      children: [
        const Expanded(child: Text('Máximo no dia')),
        // o chip só aparece com um número: sem máximo, o próprio valor já
        // diz isso e o mais é o caminho de volta
        if (atual != null)
          ActionChip(
            label: const Text('Sem máximo'),
            visualDensity: VisualDensity.compact,
            onPressed: enabled ? () => onChanged(null) : null,
          ),
        IconButton(
          onPressed: enabled && atual != null && atual > 1
              ? () => onChanged(atual - 1)
              : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        if (atual == null)
          Text(
            'Sem máximo',
            style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
          )
        else
          SizedBox(
            width: 32,
            child: Text(
              '$atual',
              textAlign: TextAlign.center,
              style: textos.titleMedium,
            ),
          ),
        IconButton(
          onPressed: enabled ? () => onChanged((atual ?? 0) + 1) : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}

// contador de 1 para cima: menos, número e mais
class _Contador extends StatelessWidget {
  const _Contador({
    required this.rotulo,
    required this.valor,
    required this.enabled,
    required this.onChanged,
  });

  final String rotulo;
  final int valor;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(rotulo)),
        IconButton(
          onPressed: enabled && valor > 1 ? () => onChanged(valor - 1) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$valor',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          onPressed: enabled ? () => onChanged(valor + 1) : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}

// o botão que copia o primeiro dia aberto para os outros, e a ajuda dos
// números da esteira: os dois ficam fora do card, nas duas telas
class RepetirDiaButton extends StatelessWidget {
  const RepetirDiaButton({
    super.key,
    required this.primeiroDiaAberto,
    required this.enabled,
    required this.onPressed,
  });

  final HorarioFuncionamento? primeiroDiaAberto;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final dia = primeiroDiaAberto;
    return OutlinedButton.icon(
      // sem dia aberto não há o que copiar
      onPressed: enabled && dia != null ? onPressed : null,
      icon: const Icon(Icons.copy_all_rounded, size: 18),
      label: Text(
        dia == null
            ? 'Repetir nos outros dias'
            : 'Repetir ${nomeCurtoDoDiaDaSemana(dia.dia)} nos outros dias',
      ),
    );
  }
}

// "segunda", "sábado": como se fala, pela tabela do core. o DiaSemana começa
// na segunda, como a lista
String nomeCurtoDoDiaDaSemana(DiaSemana dia) => nomesDosDias[dia.index];

// embaixo dos cards da esteira: por que cada dia tem os próprios números
class AjudaDosNumeros extends StatelessWidget {
  const AjudaDosNumeros({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Cada dia tem os próprios números. Quem tem ajuda só na sexta e no '
      'sábado ajusta só esses dias.',
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: BrandColors.of(context).inkMuted),
    );
  }
}
