import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/selo_de_status.dart';

import '../../domain/entities/atendimento_kanban.dart';
import '../../domain/entities/etapa.dart';

// um card do quadro: hora de entrada, cliente, o veículo ou pet (ou a
// identificação do avulso), o serviço, as marcas de pago e falta e, quando
// passou do tempo previsto, o atraso. o menu move para outra coluna
class AtendimentoKanbanCard extends StatelessWidget {
  const AtendimentoKanbanCard({
    super.key,
    required this.atendimento,
    required this.etapas,
    required this.onTap,
    required this.onMover,
    this.agora,
  });

  final AtendimentoKanban atendimento;
  final List<Etapa> etapas;
  final VoidCallback onTap;
  final ValueChanged<Etapa> onMover;

  // o momento para contar o atraso; null é agora mesmo
  final DateTime? agora;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final a = atendimento;
    final objeto = a.objeto;
    final destinos = etapas.where((e) => e.id != a.etapaId).toList();
    final atraso = a.atrasoEm(agora ?? DateTime.now());

    // no canto: o atraso é atenção (warning), o avulso é neutro, pago e
    // falta são status. atraso não convive com pago nem com falta
    final marcas = <Widget>[
      if (atraso > 0)
        SeloDeStatus(
          texto: '+${formatarDuracao(atraso)}',
          cor: cores.warning,
          icone: Icons.timer_outlined,
        ),
      if (a.ehAvulso) _Marca(texto: 'Avulso', cor: cores.inkMuted),
      if (a.pago) _Marca(texto: 'Pago', cor: cores.success),
      if (a.faltou) _Marca(texto: 'Faltou', cor: cores.danger),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: BrandSpacing.space2,
        vertical: BrandSpacing.space1,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BrandRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            BrandSpacing.space3,
            BrandSpacing.space2,
            BrandSpacing.space1,
            BrandSpacing.space2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: BrandSpacing.space1),
                        Text(
                          a.horarioEntrada == null
                              ? 'Sem hora'
                              : formatarHora(a.horarioEntrada!),
                          style: textos.bodySmall,
                        ),
                        const Spacer(),
                        for (final (i, marca) in marcas.indexed) ...[
                          if (i > 0) const SizedBox(width: BrandSpacing.space1),
                          marca,
                        ],
                      ],
                    ),
                    const SizedBox(height: BrandSpacing.space1),
                    // o cliente ou, no avulso, a identificação
                    Text(
                      a.rotulo,
                      style: textos.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (objeto != null)
                      Text(
                        [
                          objeto.titulo,
                          if (objeto.detalhe.isNotEmpty) objeto.detalhe,
                        ].join(' · '),
                        style: textos.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: BrandSpacing.space1),
                    Text(
                      [
                        '${a.servicoNome} · ${formatarDinheiro(a.valorTotal)}',
                        if (a.colaboradorNome.isNotEmpty) a.colaboradorNome,
                      ].join(' · '),
                      style: textos.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (destinos.isNotEmpty)
                PopupMenuButton<Etapa>(
                  tooltip: 'Mover para',
                  icon: const Icon(Icons.drive_file_move_rounded),
                  onSelected: onMover,
                  itemBuilder: (context) => [
                    for (final e in destinos)
                      PopupMenuItem(value: e, child: Text(e.nome)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca({required this.texto, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    // a cor do status vai só no texto; o fundo é o do card, com a borda fina
    return Container(
      padding: const EdgeInsets.all(BrandSpacing.space1),
      decoration: BoxDecoration(
        border: Border.all(color: BrandColors.of(context).border),
        borderRadius: BrandRadius.smAll,
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cor),
      ),
    );
  }
}
