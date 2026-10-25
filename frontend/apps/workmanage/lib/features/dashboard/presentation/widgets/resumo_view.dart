import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';

import '../../dashboard_provider.dart';
import '../../domain/entities/dashboard_resumo.dart';

// o resumo do mês: os números, o ranking de serviços e o dia de hoje. vive
// dentro da aba Caixa, como o segundo segmento
class ResumoView extends ConsumerStatefulWidget {
  const ResumoView({super.key});

  @override
  ConsumerState<ResumoView> createState() => _ResumoViewState();
}

class _ResumoViewState extends ConsumerState<ResumoView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(resumoProvider).carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto o segmento estiver aberto
    final provider = ref.watch(resumoProvider);

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final resumo = provider.resumo;
        if (resumo == null) {
          final erro = provider.erroAoCarregar;
          if (erro != null) {
            return EstadoErro(
              mensagem: erro.message,
              onTentarDeNovo: provider.carregar,
            );
          }
          return const Carregando();
        }
        return RefreshIndicator(
          onRefresh: provider.carregar,
          child: _conteudo(context, resumo),
        );
      },
    );
  }

  Widget _conteudo(BuildContext context, DashboardResumo resumo) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Este mês', style: textos.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _Kpi(
                rotulo: 'Faturamento',
                valor: formatarDinheiro(resumo.faturamentoMes),
                variacao: resumo.faturamentoVariacao,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Kpi(
                rotulo: 'Atendimentos',
                valor: '${resumo.atendimentosMes}',
                variacao: resumo.atendimentosVariacao,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Kpi(
                rotulo: 'Ticket médio',
                valor: formatarDinheiro(resumo.ticketMedio),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Kpi(
                rotulo: 'Clientes novos',
                valor: '${resumo.clientesNovosMes}',
                variacao: resumo.clientesNovosVariacao,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        Text('Serviços mais feitos', style: textos.titleMedium),
        const SizedBox(height: 4),
        if (resumo.rankingServicos.isEmpty)
          Text(
            'Nenhum atendimento cobrado neste mês ainda.',
            style: TextStyle(color: colors.onSurfaceVariant),
          )
        else
          for (final (i, r) in resumo.rankingServicos.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: colors.secondaryContainer,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ),
              title: Text(r.nome),
              trailing: Text('${r.total}'),
            ),

        const SizedBox(height: 24),
        Text('Hoje', style: textos.titleMedium),
        const SizedBox(height: 4),
        if (resumo.agendamentosHoje.isEmpty)
          Text(
            'Nada marcado para hoje.',
            style: TextStyle(color: colors.onSurfaceVariant),
          )
        else
          for (final a in resumo.agendamentosHoje)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(
                a.hora,
                style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              title: Text(a.clienteNome),
              subtitle: Text(a.servicoNome),
              trailing: resumo.isKanban
                  ? null
                  : const Icon(Icons.chevron_right),
              // no kanban o id é de atendimento, que este app ainda não abre
              onTap: resumo.isKanban
                  ? null
                  : () => context.push('/agenda/${a.id}'),
            ),
      ],
    );
  }
}

// um número do mês com a variação sobre o mês anterior
class _Kpi extends StatelessWidget {
  const _Kpi({required this.rotulo, required this.valor, this.variacao});

  final String rotulo;
  final String valor;
  final int? variacao;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final v = variacao;
    final subiu = v != null && v > 0;
    final caiu = v != null && v < 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: textos.bodySmall),
          const SizedBox(height: 4),
          Text(
            valor,
            style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (v != null) ...[
            const SizedBox(height: 4),
            Text(
              '${v > 0 ? '+' : ''}$v% vs. mês anterior',
              style: textos.bodySmall?.copyWith(
                color: subiu
                    ? Colors.green.shade700
                    : caiu
                    ? colors.error
                    : colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
