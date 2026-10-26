import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/faixa_semana.dart';

import '../../domain/entities/etapa.dart';
import '../../kanban_provider.dart';
import '../providers/quadro_provider.dart';
import '../widgets/atendimento_kanban_card.dart';
import '../widgets/cor_da_etapa.dart';

// o quadro da esteira: um dia por vez, as etapas em colunas e os cards em
// cada uma. receber e a ficha abrem por cima; ao voltar, o dia é relido
class QuadroPage extends ConsumerStatefulWidget {
  const QuadroPage({super.key});

  @override
  ConsumerState<QuadroPage> createState() => _QuadroPageState();
}

class _QuadroPageState extends ConsumerState<QuadroPage> {
  QuadroProvider get _provider => ref.read(quadroProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
  }

  Future<void> _abrir(String rota) async {
    await context.push(rota);
    if (mounted) _provider.recarregar();
  }

  Future<void> _escolherData() async {
    final dia = _provider.dia;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: dia,
      firstDate: DateTime(dia.year - 2),
      lastDate: DateTime(dia.year + 2, 12, 31),
    );
    if (escolhida != null) _provider.selecionarDia(escolhida);
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a aba estiver aberta
    final provider = ref.watch(quadroProvider);
    final colors = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: InkWell(
              onTap: _escolherData,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatarMesAno(provider.dia)),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            actions: [
              if (!provider.ehHoje)
                TextButton(
                  onPressed: provider.irParaHoje,
                  child: const Text('Hoje'),
                ),
              IconButton(
                tooltip: 'Cobranças pendentes',
                onPressed: () => _abrir('/agenda/pendencias'),
                icon: Badge(
                  isLabelVisible: provider.pendencias > 0,
                  label: Text('${provider.pendencias}'),
                  child: const Icon(Icons.pending_actions_outlined),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                _abrir('/quadro/novo?data=${dataParaApi(provider.dia)}'),
            icon: const Icon(Icons.add),
            label: const Text('Receber'),
          ),
          body: Column(
            children: [
              FaixaSemana(
                dia: provider.dia,
                hoje: provider.hoje,
                // o quadro não tem as bolinhas: a API não lista dias com
                // registro para a esteira
                temRegistro: (_) => false,
                onSelecionar: provider.selecionarDia,
              ),
              if (provider.colaboradores.isNotEmpty)
                _FiltroColaboradores(provider: provider),
              if (provider.isLoading && provider.carregado)
                const LinearProgressIndicator(minHeight: 2)
              else
                const Divider(height: 2),
              if (provider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    provider.errorMessage!,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              Expanded(child: _corpo(provider)),
            ],
          ),
        );
      },
    );
  }

  Widget _corpo(QuadroProvider provider) {
    if (!provider.carregado) {
      final erro = provider.erroAoCarregar;
      if (erro != null) {
        return EstadoErro(
          mensagem: erro.message,
          onTentarDeNovo: provider.carregar,
        );
      }
      return const Carregando();
    }

    final largura = MediaQuery.sizeOf(context).width;
    // no celular uma coluna quase inteira por vez; no tablet várias
    final larguraColuna = largura < 600 ? largura * 0.85 : 300.0;

    return RefreshIndicator(
      onRefresh: provider.recarregar,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
        children: [
          for (final etapa in provider.etapas)
            SizedBox(
              width: larguraColuna,
              child: _Coluna(
                etapa: etapa,
                etapas: provider.etapas,
                provider: provider,
                onAbrir: (id) => _abrir('/quadro/$id'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Coluna extends StatelessWidget {
  const _Coluna({
    required this.etapa,
    required this.etapas,
    required this.provider,
    required this.onAbrir,
  });

  final Etapa etapa;
  final List<Etapa> etapas;
  final QuadroProvider provider;
  final ValueChanged<int> onAbrir;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final cards = provider.naEtapa(etapa.id);
    final cor = corDaEtapa(etapa.cor, colors);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: cor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    etapa.nome,
                    style: textos.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${cards.length}',
                  style: textos.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: cards.isEmpty
                ? Center(
                    child: Text(
                      'Nada aqui',
                      style: TextStyle(color: colors.outline),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      for (final a in cards)
                        AtendimentoKanbanCard(
                          atendimento: a,
                          etapas: etapas,
                          onTap: () => onAbrir(a.id),
                          onMover: (destino) =>
                              provider.mover(a.id, destino.id),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// os chips de profissional: todos, ou um da equipe. o filtro vai para a API
class _FiltroColaboradores extends StatelessWidget {
  const _FiltroColaboradores({required this.provider});

  final QuadroProvider provider;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todos'),
              selected: provider.colaboradorId == null,
              onSelected: (_) => provider.filtrarColaborador(null),
            ),
          ),
          for (final c in provider.colaboradores)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c.nome),
                selected: provider.colaboradorId == c.id,
                onSelected: (_) => provider.filtrarColaborador(c.id),
              ),
            ),
        ],
      ),
    );
  }
}
