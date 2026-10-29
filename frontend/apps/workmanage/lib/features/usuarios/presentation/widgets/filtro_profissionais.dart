import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/widgets/avatar_iniciais.dart';

import '../../domain/entities/colaborador.dart';

// o filtro por profissional da agenda, do quadro e de onde mais a equipe
// filtra: uma fileira de avatares, "Todos" primeiro. o escolhido ganha o
// anel na cor primária. null em selecionadoId é todos
class FiltroProfissionais extends StatelessWidget {
  const FiltroProfissionais({
    super.key,
    required this.colaboradores,
    required this.selecionadoId,
    required this.onSelecionar,
  });

  final List<Colaborador> colaboradores;
  final int? selecionadoId;
  final ValueChanged<int?> onSelecionar;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);

    return SizedBox(
      height: 76,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BrandSpacing.space2),
        children: [
          _Item(
            nome: 'Todos',
            selecionado: selecionadoId == null,
            avatar: CircleAvatar(
              radius: 20,
              backgroundColor: cores.bg2,
              child: Icon(Icons.groups_rounded, color: cores.inkMuted),
            ),
            onTap: () => onSelecionar(null),
          ),
          for (final c in colaboradores)
            _Item(
              nome: c.nome,
              selecionado: selecionadoId == c.id,
              avatar: AvatarIniciais(nome: c.nome),
              onTap: () => onSelecionar(c.id),
            ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.nome,
    required this.selecionado,
    required this.avatar,
    required this.onTap,
  });

  final String nome;
  final bool selecionado;
  final Widget avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BrandRadius.mdAll,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // o anel do escolhido: 2 px de azul com 2 px de folga até o
            // avatar (medida do anel, não espaçamento)
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selecionado ? colors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: avatar,
            ),
            const SizedBox(height: BrandSpacing.space1),
            Text(
              // só o primeiro nome cabe embaixo do avatar
              nome.trim().split(RegExp(r'\s+')).first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // o escolhido se marca pelo anel e pela cor; o peso é o do papel
              style: textos.labelSmall?.copyWith(
                color: selecionado ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
