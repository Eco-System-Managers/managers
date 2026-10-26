import 'package:flutter/material.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/campo_data.dart';
import 'package:managers/core/widgets/folha.dart';

import '../../domain/entities/slot.dart';
import 'slots_grade.dart';

// a folha para remarcar: outro dia e, com profissional e serviço, a grade
// de horários dele. sem grade, a pessoa escolhe a hora livremente
class RemarcarSheet extends StatefulWidget {
  const RemarcarSheet({
    super.key,
    required this.dataHoraAtual,
    required this.temGrade,
    required this.buscarSlots,
  });

  final DateTime dataHoraAtual;
  final bool temGrade;
  final Future<List<Slot>> Function(DateTime data) buscarSlots;

  // devolve a nova data e hora, ou null se desistiu
  static Future<DateTime?> abrir(
    BuildContext context, {
    required DateTime dataHoraAtual,
    required bool temGrade,
    required Future<List<Slot>> Function(DateTime data) buscarSlots,
  }) {
    return abrirFolha<DateTime>(
      context,
      builder: (_) => RemarcarSheet(
        dataHoraAtual: dataHoraAtual,
        temGrade: temGrade,
        buscarSlots: buscarSlots,
      ),
    );
  }

  @override
  State<RemarcarSheet> createState() => _RemarcarSheetState();
}

class _RemarcarSheetState extends State<RemarcarSheet> {
  late DateTime _data = somenteData(widget.dataHoraAtual);
  Hora? _hora;
  List<Slot> _slots = const [];
  bool _carregando = false;

  // cada busca tem um número: a resposta de uma busca antiga é descartada
  int _busca = 0;

  @override
  void initState() {
    super.initState();
    if (widget.temGrade) _carregarSlots();
  }

  Future<void> _carregarSlots() async {
    final busca = ++_busca;
    setState(() => _carregando = true);
    final slots = await widget.buscarSlots(_data);
    if (!mounted || busca != _busca) return;
    setState(() {
      _slots = slots;
      _carregando = false;
    });
  }

  void _mudarData(DateTime? data) {
    if (data == null) return;
    setState(() {
      _data = somenteData(data);
      _hora = null;
    });
    if (widget.temGrade) _carregarSlots();
  }

  Future<void> _escolherHora() async {
    final atual = _hora ?? horaDe(widget.dataHoraAtual);
    final escolhida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: atual.hora, minute: atual.minuto),
    );
    if (escolhida == null) return;
    setState(() => _hora = (hora: escolhida.hour, minuto: escolhida.minute));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hoje = somenteData(DateTime.now());
    final hora = _hora;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text('Remarcar', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Hoje marcado para ${formatarDataHora(widget.dataHoraAtual)}',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        CampoData(
          valor: _data,
          onChanged: _mudarData,
          label: 'Novo dia',
          limpavel: false,
          primeiraData: hoje,
          ultimaData: DateTime(hoje.year + 1, hoje.month, hoje.day),
        ),
        const SizedBox(height: 16),
        if (widget.temGrade)
          SlotsGrade(
            slots: _slots,
            selecionada: _hora,
            carregando: _carregando,
            onSelecionar: (h) => setState(() => _hora = h),
          )
        else
          OutlinedButton.icon(
            onPressed: _escolherHora,
            icon: const Icon(Icons.access_time),
            label: Text(hora == null ? 'Escolher hora' : formatarHora(hora)),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: hora == null
              ? null
              : () => Navigator.of(context).pop(juntarDataHora(_data, hora)),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Remarcar'),
        ),
      ],
    );
  }
}
