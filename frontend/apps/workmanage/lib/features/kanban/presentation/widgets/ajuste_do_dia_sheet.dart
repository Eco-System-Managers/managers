import 'dart:math';

import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/folha.dart';

import '../../domain/entities/capacidade_do_dia.dart';

// salva o ajuste; devolve a mensagem de erro ou null quando deu certo
typedef SalvarAjusteDoDia = Future<String?> Function({
  int? capacidade,
  required int vagas,
});

// a folha do ajuste de uma data: o máximo no dia (ou sem máximo) e quantos
// atendimentos andam ao mesmo tempo, só para aquele dia; o padrão da semana
// continua igual. só o proprietário mexe, os outros só leem. fecha com true
// quando salvou ou voltou ao padrão
class AjusteDoDiaSheet extends StatefulWidget {
  const AjusteDoDiaSheet({
    super.key,
    required this.capacidade,
    required this.podeEditar,
    required this.onSalvar,
    required this.onVoltarAoPadrao,
  });

  final CapacidadeDoDia capacidade;
  final bool podeEditar;
  final SalvarAjusteDoDia onSalvar;

  // apaga o ajuste da data; devolve a mensagem de erro ou null
  final Future<String?> Function() onVoltarAoPadrao;

  static Future<bool?> abrir(
    BuildContext context, {
    required CapacidadeDoDia capacidade,
    required bool podeEditar,
    required SalvarAjusteDoDia onSalvar,
    required Future<String?> Function() onVoltarAoPadrao,
  }) {
    return abrirFolha<bool>(
      context,
      builder: (_) => AjusteDoDiaSheet(
        capacidade: capacidade,
        podeEditar: podeEditar,
        onSalvar: onSalvar,
        onVoltarAoPadrao: onVoltarAoPadrao,
      ),
    );
  }

  @override
  State<AjusteDoDiaSheet> createState() => _AjusteDoDiaSheetState();
}

class _AjusteDoDiaSheetState extends State<AjusteDoDiaSheet> {
  // null é sem máximo
  late int? _capacidade = widget.capacidade.capacidade;
  late int _vagas = widget.capacidade.vagas;

  // o último máximo com número, para voltar a ele quando "sem máximo" desliga
  late int _ultimoMaximo =
      widget.capacidade.capacidade ?? max(widget.capacidade.ocupados, 1);

  bool _salvando = false;
  String? _erro;

  bool get _mexe => widget.podeEditar && !_salvando;

  void _mudarMaximo(int delta) {
    final atual = _capacidade;
    if (atual == null) return;
    setState(() {
      _capacidade = max(1, atual + delta);
      _ultimoMaximo = _capacidade!;
    });
  }

  void _semMaximo(bool ligado) {
    setState(() => _capacidade = ligado ? null : _ultimoMaximo);
  }

  void _mudarVagas(int delta) {
    setState(() => _vagas = max(1, _vagas + delta));
  }

  Future<void> _executar(Future<String?> Function() acao) async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await acao();
    if (!mounted) return;
    if (erro != null) {
      setState(() {
        _salvando = false;
        _erro = erro;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _salvar() =>
      _executar(() => widget.onSalvar(capacidade: _capacidade, vagas: _vagas));

  Future<void> _voltarAoPadrao() => _executar(widget.onVoltarAoPadrao);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final c = widget.capacidade;
    final ocupados = c.ocupados == 1
        ? '1 atendimento no dia'
        : '${c.ocupados} atendimentos no dia';

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        BrandSpacing.space5,
        BrandSpacing.space4,
        BrandSpacing.space5,
        BrandSpacing.space5,
      ),
      children: [
        Text('Ajuste do dia', style: textos.titleLarge),
        const SizedBox(height: BrandSpacing.space1),
        Text(
          '${formatarDataPorExtenso(c.data)} · $ocupados',
          style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
        ),
        const SizedBox(height: BrandSpacing.space2),
        Text(
          widget.podeEditar
              ? 'Vale só para este dia. O padrão da semana continua igual.'
              : 'Só o proprietário muda o ajuste do dia.',
          style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
        ),
        const SizedBox(height: BrandSpacing.space4),
        _Controle(
          titulo: 'Máximo no dia',
          descricao: 'Quantos atendimentos cabem no dia, com ou sem hora.',
          valor: _capacidade == null ? 'Sem máximo' : '$_capacidade',
          habilitado: _mexe && _capacidade != null,
          onMenos: () => _mudarMaximo(-1),
          onMais: () => _mudarMaximo(1),
        ),
        if (widget.podeEditar)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('Sem máximo', style: textos.bodyMedium),
            value: _capacidade == null,
            onChanged: _salvando ? null : _semMaximo,
          ),
        const SizedBox(height: BrandSpacing.space3),
        _Controle(
          titulo: 'Ao mesmo tempo',
          descricao: 'Quantos andam juntos: boxes, banhistas.',
          valor: '$_vagas',
          habilitado: _mexe,
          onMenos: () => _mudarVagas(-1),
          onMais: () => _mudarVagas(1),
        ),
        if (_erro != null) ...[
          const SizedBox(height: BrandSpacing.space3),
          Text(_erro!, style: textos.bodyMedium?.copyWith(color: colors.error)),
        ],
        if (widget.podeEditar) ...[
          const SizedBox(height: BrandSpacing.space5),
          FilledButton(
            onPressed: _salvando ? null : _salvar,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Salvar'),
          ),
          if (c.ajustado) ...[
            const SizedBox(height: BrandSpacing.space2),
            TextButton(
              onPressed: _salvando ? null : _voltarAoPadrao,
              child: const Text('Voltar ao padrão da semana'),
            ),
          ],
        ],
      ],
    );
  }
}

// um número com mais e menos: o título e a explicação à esquerda, o controle
// à direita
class _Controle extends StatelessWidget {
  const _Controle({
    required this.titulo,
    required this.descricao,
    required this.valor,
    required this.habilitado,
    required this.onMenos,
    required this.onMais,
  });

  final String titulo;
  final String descricao;
  final String valor;
  final bool habilitado;
  final VoidCallback onMenos;
  final VoidCallback onMais;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: textos.titleSmall),
              const SizedBox(height: BrandSpacing.space1),
              Text(
                descricao,
                style: textos.bodySmall?.copyWith(color: cores.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: BrandSpacing.space3),
        IconButton.filledTonal(
          tooltip: 'Menos',
          onPressed: habilitado ? onMenos : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40),
          child: Text(
            valor,
            textAlign: TextAlign.center,
            style: textos.titleMedium,
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Mais',
          onPressed: habilitado ? onMais : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}
