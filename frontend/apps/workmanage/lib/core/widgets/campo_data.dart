import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:managers/core/utils/datas.dart';

import 'mascara_formatter.dart';

// como a data entra no campo
enum ModoCampoData {
  // abre o calendário do sistema ao tocar: bom para escolher um dia perto
  // (a agenda, remarcar)
  calendario,

  // a pessoa digita dd/mm/aaaa com as barras entrando sozinhas: bom para
  // datas longe de hoje (nascimento). o ícone ainda abre o calendário
  digitacao,
}

// campo de data: mostra dd/mm/aaaa. o X limpa a data
class CampoData extends StatefulWidget {
  const CampoData({
    super.key,
    required this.valor,
    required this.onChanged,
    required this.label,
    this.modo = ModoCampoData.calendario,
    this.enabled = true,
    this.limpavel = true,
    this.forceErrorText,
    this.primeiraData,
    this.ultimaData,
  });

  final DateTime? valor;
  final ValueChanged<DateTime?> onChanged;
  final String label;
  final ModoCampoData modo;
  final bool enabled;

  // false: o campo sempre tem data (a agenda), sem o X de limpar
  final bool limpavel;
  final String? forceErrorText;
  final DateTime? primeiraData;
  final DateTime? ultimaData;

  // "25/10/2026" -> a data; null quando incompleta ou não existe (31/02)
  static DateTime? interpretar(String texto) {
    final partes = texto.trim().split('/');
    if (partes.length != 3 || partes[2].length != 4) return null;
    final dia = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final ano = int.tryParse(partes[2]);
    if (dia == null || mes == null || ano == null) return null;
    final data = DateTime(ano, mes, dia);
    final existe = data.year == ano && data.month == mes && data.day == dia;
    return existe ? data : null;
  }

  @override
  State<CampoData> createState() => _CampoDataState();
}

class _CampoDataState extends State<CampoData> {
  static final _mascara = MascaraFormatter('##/##/####');

  late final TextEditingController _controller;
  final _campo = GlobalKey<FormFieldState<String>>();
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _texto(widget.valor));
    // digitando, o erro só aparece quando a pessoa sai do campo (ou no
    // salvar): "25/1" no meio da digitação não é data inválida
    _foco.addListener(() {
      if (!_foco.hasFocus) _campo.currentState?.validate();
    });
  }

  @override
  void didUpdateWidget(CampoData antigo) {
    super.didUpdateWidget(antigo);
    // quem digita já está com o texto certo: só o valor vindo de fora
    // (limpar, calendário, preencher a ficha) troca o que está escrito
    if (antigo.valor != widget.valor &&
        CampoData.interpretar(_controller.text) != widget.valor) {
      _controller.text = _texto(widget.valor);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _foco.dispose();
    super.dispose();
  }

  String _texto(DateTime? data) => data == null ? '' : formatarData(data);

  DateTime get _primeira => widget.primeiraData ?? DateTime(1900);
  DateTime get _ultima => widget.ultimaData ?? DateTime.now();

  Future<void> _escolher() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: widget.valor ?? _ultima,
      firstDate: _primeira,
      lastDate: _ultima,
    );
    if (escolhida != null) widget.onChanged(escolhida);
  }

  // a cada tecla: data completa e válida sobe; incompleta ou inválida
  // vira null (o validator mostra o erro quando a pessoa sai do campo)
  void _aoDigitar(String texto) {
    final data = CampoData.interpretar(texto);
    if (data != null && (data.isBefore(_primeira) || data.isAfter(_ultima))) {
      widget.onChanged(null);
      return;
    }
    if (data != widget.valor) widget.onChanged(data);
  }

  String? _validar(String? texto) {
    if (texto == null || texto.trim().isEmpty) return null;
    if (texto.length < 10) return 'Data incompleta';
    final data = CampoData.interpretar(texto);
    if (data == null) return 'Data inválida';
    if (data.isBefore(_primeira)) return 'Antes de ${formatarData(_primeira)}';
    if (data.isAfter(_ultima)) return 'Depois de ${formatarData(_ultima)}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final digitacao = widget.modo == ModoCampoData.digitacao;
    final mostraLimpar =
        widget.valor != null && widget.enabled && widget.limpavel;

    return TextFormField(
      key: _campo,
      controller: _controller,
      focusNode: _foco,
      readOnly: !digitacao,
      enabled: widget.enabled,
      onTap: widget.enabled && !digitacao ? _escolher : null,
      keyboardType: digitacao ? TextInputType.number : null,
      inputFormatters: digitacao
          ? [FilteringTextInputFormatter.digitsOnly, _mascara]
          : null,
      onChanged: digitacao ? _aoDigitar : null,
      validator: digitacao ? _validar : null,
      forceErrorText: widget.forceErrorText,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: digitacao ? 'dd/mm/aaaa' : null,
        prefixIcon: digitacao
            ? IconButton(
                tooltip: 'Abrir calendário',
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: widget.enabled ? _escolher : null,
              )
            : const Icon(Icons.calendar_today_outlined),
        border: const OutlineInputBorder(),
        suffixIcon: mostraLimpar
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged(null);
                },
              )
            : null,
      ),
    );
  }
}
