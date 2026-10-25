import 'package:flutter/material.dart';
import 'package:managers/core/utils/datas.dart';

// campo de data: mostra dd/mm/aaaa e abre o calendário do sistema (em
// português, pela localização do app). o X limpa a data
class CampoData extends StatefulWidget {
  const CampoData({
    super.key,
    required this.valor,
    required this.onChanged,
    required this.label,
    this.enabled = true,
    this.limpavel = true,
    this.forceErrorText,
    this.primeiraData,
    this.ultimaData,
  });

  final DateTime? valor;
  final ValueChanged<DateTime?> onChanged;
  final String label;
  final bool enabled;

  // false: o campo sempre tem data (a agenda), sem o X de limpar
  final bool limpavel;
  final String? forceErrorText;
  final DateTime? primeiraData;
  final DateTime? ultimaData;

  @override
  State<CampoData> createState() => _CampoDataState();
}

class _CampoDataState extends State<CampoData> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _texto(widget.valor));
  }

  @override
  void didUpdateWidget(CampoData antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.valor != widget.valor) _controller.text = _texto(widget.valor);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _texto(DateTime? data) => data == null ? '' : formatarData(data);

  Future<void> _escolher() async {
    final ultima = widget.ultimaData ?? DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: widget.valor ?? ultima,
      firstDate: widget.primeiraData ?? DateTime(1900),
      lastDate: ultima,
    );
    if (escolhida != null) widget.onChanged(escolhida);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      readOnly: true,
      enabled: widget.enabled,
      onTap: widget.enabled ? _escolher : null,
      forceErrorText: widget.forceErrorText,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.calendar_today_outlined),
        border: const OutlineInputBorder(),
        suffixIcon: widget.valor != null && widget.enabled && widget.limpavel
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => widget.onChanged(null),
              )
            : null,
      ),
    );
  }
}
