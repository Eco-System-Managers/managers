import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/folha.dart';

import '../../domain/entities/bloqueio.dart';

// "12/11/2026", "12/11/2026 a 18/11/2026" ou "Todos os dias, desde 12/11/2026"
String descreverPeriodo(Bloqueio b) {
  final inicio = formatarData(b.dataInicio);
  final fim = b.dataFim;
  if (fim == null) return 'Todos os dias, desde $inicio';
  if (mesmoDia(fim, b.dataInicio)) return inicio;
  return '$inicio a ${formatarData(fim)}';
}

// "Dia inteiro" ou "12:00 às 13:00"
String descreverHorario(Bloqueio b) => b.diaInteiro
    ? 'Dia inteiro'
    : '${formatarHora(b.horaInicio!)} às ${formatarHora(b.horaFim!)}';

// a ficha de um bloqueio, aberta ao tocar na faixa da grade (ou na faixa
// fechada do quadro): de quem é, o período, o horário e o motivo. quem pode
// exclui; não existe editar
class BloqueioSheet extends StatefulWidget {
  const BloqueioSheet({
    super.key,
    required this.bloqueio,
    required this.excluir,
  });

  final Bloqueio bloqueio;

  // null quando quem está logado não pode excluir. devolve a mensagem de
  // erro, ou null quando excluiu
  final Future<String?> Function()? excluir;

  static Future<void> abrir(
    BuildContext context, {
    required Bloqueio bloqueio,
    required Future<String?> Function()? excluir,
  }) {
    return abrirFolha<void>(
      context,
      builder: (_) => BloqueioSheet(bloqueio: bloqueio, excluir: excluir),
    );
  }

  @override
  State<BloqueioSheet> createState() => _BloqueioSheetState();
}

class _BloqueioSheetState extends State<BloqueioSheet> {
  bool _excluindo = false;
  String? _erro;

  Future<void> _excluir() async {
    final excluir = widget.excluir;
    if (excluir == null) return;
    final ok = await confirmar(
      context,
      titulo: 'Excluir bloqueio?',
      // do negócio, o que volta é a oferta para marcar; do profissional, o
      // horário dele na agenda
      mensagem: widget.bloqueio.doNegocio
          ? 'O período volta a ser oferecido para marcar.'
          : 'O horário volta a ficar livre na agenda.',
      textoConfirmar: 'Excluir',
      destrutivo: true,
    );
    if (!ok || !mounted) return;

    setState(() {
      _excluindo = true;
      _erro = null;
    });
    final erro = await excluir();
    if (!mounted) return;
    if (erro == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _excluindo = false;
      _erro = erro;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final b = widget.bloqueio;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        BrandSpacing.space5,
        BrandSpacing.space4,
        BrandSpacing.space5,
        BrandSpacing.space5,
      ),
      children: [
        Text(
          b.motivo.isEmpty
              ? (b.doNegocio ? 'Fechado' : 'Bloqueado')
              : b.motivo,
          style: textos.titleLarge,
        ),
        const SizedBox(height: BrandSpacing.space1),
        // sem profissional é o negócio inteiro
        Text(
          b.doNegocio ? 'Todo o negócio' : b.colaboradorNome,
          style: textos.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: BrandSpacing.space4),
        _Linha(icone: Icons.event_rounded, texto: descreverPeriodo(b)),
        const SizedBox(height: BrandSpacing.space2),
        _Linha(icone: Icons.schedule_rounded, texto: descreverHorario(b)),
        if (_erro != null) ...[
          const SizedBox(height: BrandSpacing.space4),
          Text(_erro!, style: textos.bodyMedium?.copyWith(color: colors.error)),
        ],
        if (widget.excluir != null) ...[
          const SizedBox(height: BrandSpacing.space5),
          OutlinedButton.icon(
            onPressed: _excluindo ? null : _excluir,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Excluir bloqueio'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ],
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 20, color: BrandColors.of(context).inkMuted),
        const SizedBox(width: BrandSpacing.space3),
        Expanded(
          child: Text(texto, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}
