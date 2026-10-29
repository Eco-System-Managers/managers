import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';

import '../../domain/entities/nicho.dart';
import 'nicho_visual.dart';

// a escolha dos nichos, por área: um título e a grade de cards de cada uma.
// tocar só marca ou desmarca (quem salva é a tela). o que a regra não aceita
// (outra área, ou já são 4) fica desabilitado. o onboarding mostra todas as
// áreas; as configurações, só a do negócio, que não muda depois do
// onboarding. o outro fica fora do MVP: o backend aceita, o app não oferece
class NichosGrade extends StatelessWidget {
  const NichosGrade({
    super.key,
    required this.escolhidos,
    required this.onAlternar,
    this.areas = AreaNicho.values,
  });

  final List<Nicho> escolhidos;

  // null desabilita a grade inteira (salvando)
  final ValueChanged<Nicho>? onAlternar;

  final List<AreaNicho> areas;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final mostrarTitulos = areas.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final area in areas) ...[
          if (mostrarTitulos) ...[
            Text(
              area.nome,
              style: textos.titleSmall?.copyWith(color: cores.ink),
            ),
            const SizedBox(height: BrandSpacing.space2),
          ],
          _grade(area),
          const SizedBox(height: BrandSpacing.space4),
        ],
      ],
    );
  }

  Widget _grade(AreaNicho area) {
    // 3 colunas no celular, 4 no tablet
    return LayoutBuilder(
      builder: (context, constraints) {
        final colunas = constraints.maxWidth >= 560 ? 4 : 3;
        final onAlternar = this.onAlternar;

        return GridView.count(
          crossAxisCount: colunas,
          mainAxisSpacing: BrandSpacing.space3,
          crossAxisSpacing: BrandSpacing.space3,
          childAspectRatio: 0.9,
          // a rolagem é da página: a grade só ocupa a altura dela
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final nicho in Nicho.values)
              if (nicho.area == area)
                _NichoCard(
                  nicho: nicho,
                  selecionado: escolhidos.contains(nicho),
                  onTap: onAlternar != null && escolhidos.aceita(nicho)
                      ? () => onAlternar(nicho)
                      : null,
                ),
          ],
        );
      },
    );
  }
}

class _NichoCard extends StatelessWidget {
  const _NichoCard({
    required this.nicho,
    required this.selecionado,
    required this.onTap,
  });

  final Nicho nicho;
  final bool selecionado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cores = BrandColors.of(context);

    // o nicho escolhido é o azul suave com contorno azul; o conteúdo fica
    // em ink nos dois estados, e o escolhido se marca pelo fundo e pela
    // borda. o que não pode entrar vai em inkMuted
    final conteudo = selecionado || onTap != null ? cores.ink : cores.inkMuted;

    return Material(
      color: selecionado ? cores.blueSoft : cores.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BrandRadius.mdAll,
        side: BorderSide(
          color: selecionado ? colors.primary : cores.border,
          width: selecionado ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(BrandSpacing.space2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(nicho.icone, size: 32, color: conteudo),
              const SizedBox(height: BrandSpacing.space2),
              Text(
                nicho.nome,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: conteudo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
