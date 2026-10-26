import 'package:flutter/material.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';

import '../../domain/entities/atendimento_kanban.dart';
import '../../domain/entities/etapa.dart';

// um card do quadro: hora de entrada, cliente, o veículo ou pet, o serviço e
// as marcas de pago e falta. o menu move para outra coluna
class AtendimentoKanbanCard extends StatelessWidget {
  const AtendimentoKanbanCard({
    super.key,
    required this.atendimento,
    required this.etapas,
    required this.onTap,
    required this.onMover,
  });

  final AtendimentoKanban atendimento;
  final List<Etapa> etapas;
  final VoidCallback onTap;
  final ValueChanged<Etapa> onMover;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final a = atendimento;
    final destinos = etapas.where((e) => e.id != a.etapaId).toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
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
                          Icons.schedule,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          a.horarioEntrada == null
                              ? 'Sem hora'
                              : formatarHora(a.horarioEntrada!),
                          style: textos.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        if (a.pago)
                          _Marca(texto: 'Pago', cor: Colors.green.shade700),
                        if (a.faltou) ...[
                          const SizedBox(width: 4),
                          _Marca(texto: 'Faltou', cor: colors.error),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a.clienteNome,
                      style: textos.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        a.objeto.titulo,
                        if (a.objeto.detalhe.isNotEmpty) a.objeto.detalhe,
                      ].join(' · '),
                      style: textos.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        '${a.servicoNome} · ${formatarDinheiro(a.valorTotal)}',
                        if (a.colaboradorNome.isNotEmpty) a.colaboradorNome,
                      ].join(' · '),
                      style: textos.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (destinos.isNotEmpty)
                PopupMenuButton<Etapa>(
                  tooltip: 'Mover para',
                  icon: const Icon(Icons.drive_file_move_outline),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: cor.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w600),
      ),
    );
  }
}
