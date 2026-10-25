import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';

import '../../agenda_provider.dart';
import '../../domain/entities/agendamento.dart';
import 'status_agendamento_chip.dart';

// os últimos atendimentos do cliente, para a ficha dele. tocar abre o
// agendamento; "ver todos" abre a lista inteira. a ficha segue útil se
// isto falhar: o erro fica dentro do cartão
class HistoricoClienteCard extends ConsumerStatefulWidget {
  const HistoricoClienteCard({super.key, required this.clienteId});

  final int clienteId;

  // quantos cabem na ficha
  static const recentes = 5;

  @override
  ConsumerState<HistoricoClienteCard> createState() =>
      _HistoricoClienteCardState();
}

class _HistoricoClienteCardState extends ConsumerState<HistoricoClienteCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(historicoClienteProvider(widget.clienteId)).carregar();
      }
    });
  }

  // a tela aberta pode ter cobrado ou cancelado: a lista vem da API de novo
  Future<void> _abrir(String rota) async {
    await context.push(rota);
    if (mounted) {
      ref.read(historicoClienteProvider(widget.clienteId)).carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a ficha estiver aberta
    final provider = ref.watch(historicoClienteProvider(widget.clienteId));
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final erro = provider.erro;
        final recentes = provider.agendamentos
            .take(HistoricoClienteCard.recentes)
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
                  HistoricoItem(
                    agendamento: a,
                    compacto: true,
                    onTap: () => _abrir('/agenda/${a.id}'),
                  ),
                if (provider.total > HistoricoClienteCard.recentes)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          _abrir('/clientes/${widget.clienteId}/atendimentos'),
                      child: Text('Ver todos (${provider.total})'),
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

// uma linha do histórico: dia e hora, serviços, profissional, status e valor
class HistoricoItem extends StatelessWidget {
  const HistoricoItem({
    super.key,
    required this.agendamento,
    required this.onTap,
    this.compacto = false,
  });

  final Agendamento agendamento;
  final VoidCallback onTap;

  // sem padding lateral, para caber dentro de um cartão
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final a = agendamento;
    final detalhe = [
      a.servicos.map((s) => s.nome).join(', '),
      if (a.colaboradorNome != null && a.colaboradorNome!.isNotEmpty)
        a.colaboradorNome!,
    ].where((t) => t.isNotEmpty).join(' · ');

    return ListTile(
      contentPadding: compacto ? EdgeInsets.zero : null,
      dense: compacto,
      title: Text(
        '${formatarDataPorExtenso(a.dataHora)} · '
        '${formatarHora(horaDe(a.dataHora))}',
      ),
      subtitle: detalhe.isEmpty
          ? null
          : Text(detalhe, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatarDinheiro(a.valorTotal),
            style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            a.status.nome,
            style: textos.bodySmall?.copyWith(color: a.status.cor(colors)),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
