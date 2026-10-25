import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/estado_vazio.dart';
import 'package:managers/features/dashboard/presentation/widgets/resumo_view.dart';

import '../../domain/entities/caixa.dart';
import '../../financeiro_provider.dart';
import '../providers/caixa_provider.dart';

// a aba Caixa: o fechamento por período e, no segundo segmento, o resumo
// do mês (painel)
class CaixaPage extends ConsumerStatefulWidget {
  const CaixaPage({super.key});

  @override
  ConsumerState<CaixaPage> createState() => _CaixaPageState();
}

class _CaixaPageState extends ConsumerState<CaixaPage> {
  // 0: caixa, 1: resumo
  int _segmento = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(caixaProvider).carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caixa')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.point_of_sale_outlined),
                  label: Text('Caixa'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.insights_outlined),
                  label: Text('Resumo'),
                ),
              ],
              selected: {_segmento},
              onSelectionChanged: (s) => setState(() => _segmento = s.first),
            ),
          ),
          Expanded(
            child: _segmento == 0 ? const _CaixaView() : const ResumoView(),
          ),
        ],
      ),
    );
  }
}

class _CaixaView extends ConsumerStatefulWidget {
  const _CaixaView();

  @override
  ConsumerState<_CaixaView> createState() => _CaixaViewState();
}

class _CaixaViewState extends ConsumerState<_CaixaView> {
  Future<void> _escolherIntervalo(CaixaProvider provider) async {
    final hoje = DateTime.now();
    final intervalo = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: provider.inicio,
        end: provider.fim,
      ),
      firstDate: DateTime(hoje.year - 2),
      lastDate: hoje,
    );
    if (intervalo != null) {
      provider.selecionarIntervalo(intervalo.start, intervalo.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a aba estiver aberta
    final provider = ref.watch(caixaProvider);

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        return Column(
          children: [
            _Periodos(
              provider: provider,
              onPersonalizado: () => _escolherIntervalo(provider),
            ),
            if (provider.isLoading && provider.carregado)
              const LinearProgressIndicator(minHeight: 2)
            else
              const SizedBox(height: 2),
            Expanded(child: _corpo(provider)),
          ],
        );
      },
    );
  }

  Widget _corpo(CaixaProvider provider) {
    final caixa = provider.caixa;
    if (caixa == null) {
      final erro = provider.erroAoCarregar;
      if (erro != null) {
        return EstadoErro(
          mensagem: erro.message,
          onTentarDeNovo: provider.carregar,
        );
      }
      return const Carregando();
    }

    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: provider.carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _Kpi(
                  rotulo: 'Total',
                  valor: formatarDinheiro(caixa.total),
                  destaque: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Kpi(
                  rotulo: 'Atendimentos',
                  valor: '${caixa.atendimentos}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Kpi(
                  rotulo: 'Ticket médio',
                  valor: formatarDinheiro(caixa.ticketMedio),
                ),
              ),
            ],
          ),

          if (caixa.porForma.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Por forma de pagamento', style: textos.titleMedium),
            const SizedBox(height: 8),
            for (final f in caixa.porForma) ...[
              Row(
                children: [
                  Expanded(child: Text(nomeDaForma(f.forma))),
                  Text('${f.percentual}%', style: textos.bodySmall),
                  const SizedBox(width: 12),
                  Text(
                    formatarDinheiro(f.total),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: f.percentual / 100,
                  minHeight: 6,
                  backgroundColor: colors.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],

          const SizedBox(height: 16),
          Text('Pagamentos', style: textos.titleMedium),
          if (caixa.pagamentos.isEmpty)
            const EstadoVazio(
              icone: Icons.receipt_long_outlined,
              titulo: 'Nenhum pagamento no período',
              mensagem: 'As cobranças feitas na agenda aparecem aqui.',
            )
          else
            for (final p in caixa.pagamentos)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.clienteNome),
                subtitle: Text(
                  [
                    p.servicoNome,
                    if (p.colaboradorNome.isNotEmpty) p.colaboradorNome,
                    nomeDaForma(p.forma),
                  ].join(' · '),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatarDinheiro(p.valor),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(formatarDataHora(p.dataHora), style: textos.bodySmall),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// os atalhos de período e o intervalo escolhido
class _Periodos extends StatelessWidget {
  const _Periodos({required this.provider, required this.onPersonalizado});

  final CaixaProvider provider;
  final VoidCallback onPersonalizado;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final intervalo = mesmoDia(provider.inicio, provider.fim)
        ? formatarData(provider.inicio)
        : '${formatarData(provider.inicio)} a ${formatarData(provider.fim)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final (periodo, rotulo) in const [
                (PeriodoCaixa.hoje, 'Hoje'),
                (PeriodoCaixa.semana, '7 dias'),
                (PeriodoCaixa.mes, 'Este mês'),
              ])
                ChoiceChip(
                  label: Text(rotulo),
                  selected: provider.periodo == periodo,
                  onSelected: (_) => provider.selecionarPeriodo(periodo),
                ),
              ChoiceChip(
                label: const Text('Período'),
                avatar: const Icon(Icons.date_range, size: 18),
                selected: provider.periodo == PeriodoCaixa.personalizado,
                onSelected: (_) => onPersonalizado(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(intervalo, style: TextStyle(color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.rotulo,
    required this.valor,
    this.destaque = false,
  });

  final String rotulo;
  final String valor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: destaque
            ? colors.primaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo,
            style: textos.bodySmall?.copyWith(
              color: destaque ? colors.onPrimaryContainer : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: textos.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: destaque ? colors.onPrimaryContainer : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
