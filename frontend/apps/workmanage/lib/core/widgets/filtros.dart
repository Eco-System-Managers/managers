import 'package:flutter/material.dart';

import 'folha.dart';

// os filtros das telas de números (Início, Caixa): chips iguais que abrem
// uma folha de opções com a escolhida marcada

class ChipDeFiltro extends StatelessWidget {
  const ChipDeFiltro({
    super.key,
    required this.icone,
    required this.texto,
    required this.onTap,
  });

  final IconData icone;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Material(
      color: colors.surfaceContainerLow,
      shape: StadiumBorder(side: BorderSide(color: colors.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                texto,
                style: textos.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// abre a folha com as opções e devolve a escolhida (null se fechou)
Future<T?> escolherNaFolha<T>(
  BuildContext context, {
  required String titulo,
  required List<OpcaoDaFolha<T>> opcoes,
}) {
  return abrirFolha<T>(
    context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final o in opcoes)
          _LinhaDaOpcao(
            opcao: o,
            onTap: () => Navigator.of(context).pop(o.valor),
          ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

class OpcaoDaFolha<T> {
  const OpcaoDaFolha({
    required this.valor,
    required this.texto,
    this.selecionada = false,
    this.icone,
    this.avatar,
  });

  final T valor;
  final String texto;
  final bool selecionada;
  final IconData? icone;
  final Widget? avatar;
}

class _LinhaDaOpcao extends StatelessWidget {
  const _LinhaDaOpcao({required this.opcao, required this.onTap});

  final OpcaoDaFolha opcao;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading:
          opcao.avatar ??
          (opcao.icone == null
              ? const SizedBox(width: 32)
              : Icon(opcao.icone, color: colors.onSurfaceVariant)),
      title: Text(
        opcao.texto,
        style: TextStyle(
          fontWeight: opcao.selecionada ? FontWeight.w700 : null,
          color: opcao.selecionada ? colors.primary : null,
        ),
      ),
      trailing: opcao.selecionada
          ? Icon(Icons.check, color: colors.primary)
          : null,
      onTap: onTap,
    );
  }
}

// "Ana Silva" -> "Ana"
String primeiroNome(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+'));
  return partes.isEmpty ? '' : partes.first;
}
