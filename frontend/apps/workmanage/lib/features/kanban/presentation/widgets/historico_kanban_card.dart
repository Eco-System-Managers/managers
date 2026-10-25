import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';

import '../../kanban_provider.dart';

// os últimos atendimentos do cliente na esteira, para a ficha dele. tocar
// abre o card. a ficha segue útil se isto falhar: o erro fica no cartão
class HistoricoKanbanCard extends ConsumerStatefulWidget {
  const HistoricoKanbanCard({super.key, required this.clienteId});

  final int clienteId;

  // quantos cabem na ficha
  static const recentes = 8;

  @override
  ConsumerState<HistoricoKanbanCard> createState() =>
      _HistoricoKanbanCardState();
}

class _HistoricoKanbanCardState extends ConsumerState<HistoricoKanbanCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(historicoKanbanProvider(widget.clienteId)).carregar();
      }
    });
  }

  Future<void> _abrir(int id) async {
    await context.push('/quadro/$id');
    if (mounted) {
      ref.read(historicoKanbanProvider(widget.clienteId)).carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a ficha estiver aberta
    final provider = ref.watch(historicoKanbanProvider(widget.clienteId));
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final erro = provider.erro;
        final recentes = provider.atendimentos
            .take(HistoricoKanbanCard.recentes)
            .toList();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_note_outlined, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Atendimentos', style: textos.titleSmall),
                    ),
                    if (provider.carregado)
                      Text(
                        provider.total == 0
                            ? 'nenhum'
                            : '${provider.total} · '
                                  '${formatarDinheiro(provider.totalPago)}',
                        style: textos.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      )
                    else if (erro == null)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                if (erro != null) ...[
                  const SizedBox(height: 8),
                  Text(erro.message, style: TextStyle(color: colors.error)),
                  TextButton(
                    onPressed: provider.carregar,
                    child: const Text('Tentar de novo'),
                  ),
                ],
                if (provider.carregado && provider.total == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(
                      'Nenhum atendimento ainda.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                for (final a in recentes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      [
                        if (a.data != null) formatarDataPorExtenso(a.data!),
                        if (a.horarioEntrada != null)
                          formatarHora(a.horarioEntrada!),
                      ].join(' · '),
                    ),
                    subtitle: Text(
                      '${a.objeto.titulo} · ${a.servicoNome}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatarDinheiro(a.valorTotal),
                          style: textos.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          a.faltou
                              ? 'Faltou'
                              : a.pago
                              ? 'Pago'
                              : a.etapaNome,
                          style: textos.bodySmall?.copyWith(
                            color: a.faltou
                                ? colors.error
                                : a.pago
                                ? Colors.green.shade700
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _abrir(a.id),
                  ),
                if (provider.total > HistoricoKanbanCard.recentes)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'e mais ${provider.total - HistoricoKanbanCard.recentes}',
                      style: textos.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
