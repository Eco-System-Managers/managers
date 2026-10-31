import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/campo_data.dart';
import 'package:managers/core/widgets/folha.dart';

// para onde o atendimento vai: o dia e a hora de entrada (null é sem hora
// marcada)
typedef DestinoDaRemarcacao = ({DateTime data, Hora? hora});

// a folha para remarcar na esteira: outro dia e, nele, a grade de horas em
// que o serviço cabe, ou sem hora marcada. devolve o destino, ou null se
// desistiu
class RemarcarKanbanSheet extends StatefulWidget {
  const RemarcarKanbanSheet({
    super.key,
    required this.dataAtual,
    required this.horaAtual,
    required this.buscarSlots,
  });

  final DateTime dataAtual;
  final Hora? horaAtual;

  // as horas em que o serviço cabe num dia (a grade do serviço)
  final Future<List<Hora>> Function(DateTime data) buscarSlots;

  static Future<DestinoDaRemarcacao?> abrir(
    BuildContext context, {
    required DateTime dataAtual,
    required Hora? horaAtual,
    required Future<List<Hora>> Function(DateTime data) buscarSlots,
  }) {
    return abrirFolha<DestinoDaRemarcacao>(
      context,
      builder: (_) => RemarcarKanbanSheet(
        dataAtual: dataAtual,
        horaAtual: horaAtual,
        buscarSlots: buscarSlots,
      ),
    );
  }

  @override
  State<RemarcarKanbanSheet> createState() => _RemarcarKanbanSheetState();
}

class _RemarcarKanbanSheetState extends State<RemarcarKanbanSheet> {
  late DateTime _data = somenteData(widget.dataAtual);

  // começa sem hora: a grade do dia é que oferece as horas
  Hora? _hora;
  List<Hora> _slots = const [];
  bool _carregando = false;

  // cada busca tem um número: a resposta de uma busca antiga é descartada
  int _busca = 0;

  @override
  void initState() {
    super.initState();
    _carregarSlots();
  }

  Future<void> _carregarSlots() async {
    final busca = ++_busca;
    setState(() => _carregando = true);
    final slots = await widget.buscarSlots(_data);
    if (!mounted || busca != _busca) return;
    setState(() {
      _slots = slots;
      _carregando = false;
      if (_hora != null && !slots.contains(_hora)) _hora = null;
    });
  }

  void _mudarData(DateTime? data) {
    if (data == null) return;
    setState(() {
      _data = somenteData(data);
      _hora = null;
    });
    _carregarSlots();
  }

  // só vale remarcar quando algo muda
  bool get _mudou =>
      !mesmoDia(_data, widget.dataAtual) || _hora != widget.horaAtual;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final hoje = somenteData(DateTime.now());
    final horaAtual = widget.horaAtual;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        BrandSpacing.space5,
        BrandSpacing.space4,
        BrandSpacing.space5,
        BrandSpacing.space5,
      ),
      children: [
        Text('Remarcar', style: textos.titleLarge),
        const SizedBox(height: BrandSpacing.space1),
        Text(
          'Marcado para ${formatarDataPorExtenso(widget.dataAtual)}'
          '${horaAtual == null ? ', sem hora marcada' : ', às ${formatarHora(horaAtual)}'}',
          style: textos.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: BrandSpacing.space4),
        CampoData(
          valor: _data,
          onChanged: _mudarData,
          label: 'Novo dia',
          limpavel: false,
          primeiraData: DateTime(hoje.year - 1, hoje.month, hoje.day),
          ultimaData: DateTime(hoje.year + 1, hoje.month, hoje.day),
        ),
        const SizedBox(height: BrandSpacing.space4),
        Text('Hora de entrada', style: textos.titleSmall),
        const SizedBox(height: BrandSpacing.space2),
        if (_carregando)
          const Padding(
            padding: EdgeInsets.all(BrandSpacing.space4),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          Wrap(
            spacing: BrandSpacing.space2,
            runSpacing: BrandSpacing.space2,
            children: [
              ChoiceChip(
                label: const Text('Sem hora marcada'),
                selected: _hora == null,
                onSelected: (_) => setState(() => _hora = null),
              ),
              for (final hora in _slots)
                ChoiceChip(
                  label: Text(formatarHora(hora)),
                  selected: _hora == hora,
                  onSelected: (_) => setState(() => _hora = hora),
                ),
            ],
          ),
          if (_slots.isEmpty) ...[
            const SizedBox(height: BrandSpacing.space2),
            Text(
              'Sem hora livre para este serviço neste dia. Dá para remarcar '
              'sem hora marcada.',
              style: textos.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
        const SizedBox(height: BrandSpacing.space5),
        FilledButton(
          onPressed: _mudou
              ? () => Navigator.of(context).pop((data: _data, hora: _hora))
              : null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Remarcar'),
        ),
      ],
    );
  }
}
