import 'package:flutter/material.dart';

import '../theme/brand.dart';
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
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

    // um chip: raio sm com a borda fina, texto em title-small
    return Material(
      color: cores.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BrandRadius.smAll,
        side: BorderSide(color: cores.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            BrandSpacing.space3,
            BrandSpacing.space2,
            BrandSpacing.space2,
            BrandSpacing.space2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: BrandSpacing.space1),
              Text(texto, style: textos.titleSmall),
              Icon(
                Icons.arrow_drop_down_rounded,
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

// abre a folha com as opções e devolve a escolhida (null se fechou). a
// descrição, quando vem, explica a escolha embaixo do título
Future<T?> escolherNaFolha<T>(
  BuildContext context, {
  required String titulo,
  required List<OpcaoDaFolha<T>> opcoes,
  String? descricao,
}) {
  return abrirFolha<T>(
    context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BrandSpacing.space5,
            BrandSpacing.space4,
            BrandSpacing.space5,
            BrandSpacing.space2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // o título da folha é um título de seção: h3
              Text(titulo, style: Theme.of(context).textTheme.titleLarge),
              if (descricao != null) ...[
                const SizedBox(height: BrandSpacing.space1),
                Text(
                  descricao,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: BrandColors.of(context).inkMuted),
                ),
              ],
            ],
          ),
        ),
        for (final o in opcoes)
          _LinhaDaOpcao(
            opcao: o,
            onTap: () => Navigator.of(context).pop(o.valor),
          ),
        const SizedBox(height: BrandSpacing.space2),
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
    final textos = Theme.of(context).textTheme;
    return ListTile(
      leading:
          opcao.avatar ??
          (opcao.icone == null
              // o lugar do ícone, para os textos alinharem
              ? const SizedBox(width: 32)
              : Icon(opcao.icone, color: colors.onSurfaceVariant)),
      // a escolhida é o estado ativo: azul em body-strong; as outras, body
      titleTextStyle: opcao.selecionada
          ? textos.titleMedium?.copyWith(color: colors.primary)
          : textos.bodyMedium,
      title: Text(opcao.texto),
      trailing: opcao.selecionada
          ? Icon(Icons.check_rounded, color: colors.primary)
          : null,
      onTap: onTap,
    );
  }
}
