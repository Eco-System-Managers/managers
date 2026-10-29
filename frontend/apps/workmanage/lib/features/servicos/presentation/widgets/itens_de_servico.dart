import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/features/empresa/domain/entities/nicho.dart';
import 'package:managers/features/empresa/presentation/widgets/nicho_visual.dart';

import '../../domain/entities/servico.dart';

// os itens do dropdown de serviço da agenda e do quadro. quando os serviços
// são de mais de um nicho, cada nicho ganha um título discreto (não
// escolhível) e os serviços dele vêm embaixo, na ordem de exibição dos
// nichos; com um nicho só, a lista fica corrida, como sempre foi
List<DropdownMenuItem<Servico>> itensDeServico(
  BuildContext context, {
  required List<Servico> servicos,
  required String Function(Servico servico) rotulo,
}) {
  DropdownMenuItem<Servico> item(Servico s) => DropdownMenuItem(
    value: s,
    child: Text(rotulo(s), overflow: TextOverflow.ellipsis),
  );

  // na ordem de exibição dos nichos; serviço sem nicho vai por último
  int ordem(Nicho? n) => n?.index ?? Nicho.values.length;
  final nichos = {for (final s in servicos) s.nicho}.toList()
    ..sort((a, b) => ordem(a).compareTo(ordem(b)));
  if (nichos.length < 2) return [for (final s in servicos) item(s)];

  final cores = BrandColors.of(context);
  final estilo = Theme.of(context).textTheme.labelSmall
      ?.copyWith(color: cores.inkMuted);

  return [
    for (final nicho in nichos) ...[
      DropdownMenuItem<Servico>(
        enabled: false,
        child: Text(nicho?.nome ?? 'Outros', style: estilo),
      ),
      for (final s in servicos)
        if (s.nicho == nicho) item(s),
    ],
  ];
}
