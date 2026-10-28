import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/faixa_semana.dart';
import 'package:managers/core/widgets/sombra_de_borda.dart';
import 'package:managers/features/usuarios/presentation/widgets/filtro_profissionais.dart';

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

  // o mês inteiro aberto em cima do quadro
  bool _mesAberto = false;

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

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a aba estiver aberta
    final provider = ref.watch(quadroProvider);
    final colors = Theme.of(context).colorScheme;
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            // o dia por extenso; com o mês aberto, o mês. tocar abre e fecha
            title: InkWell(
              onTap: () => setState(() => _mesAberto = !_mesAberto),
              borderRadius: BrandRadius.smAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BrandSpacing.space1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _mesAberto
                            ? formatarMesAno(provider.dia)
                            : formatarDataPorExtenso(provider.dia),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AnimatedRotation(
                      turns: _mesAberto ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.arrow_drop_down_rounded),
                    ),
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
                // pendente é atenção: o contador em warning, como na agenda e
                // no Início (o badge do tema é danger)
                icon: Badge(
                  isLabelVisible: provider.pendencias > 0,
                  backgroundColor: cores.warning,
                  textColor: cores.bg,
                  label: Text('${provider.pendencias}'),
                  child: const Icon(Icons.pending_actions_rounded),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                _abrir('/quadro/novo?data=${dataParaApi(provider.dia)}'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Receber'),
          ),
          body: comSombraEmBaixo(
            Column(
              children: [
                FaixaSemana(
                  dia: provider.dia,
                  hoje: provider.hoje,
                  // o quadro não tem as bolinhas: a API não lista dias com
                  // registro para a esteira
                  temRegistro: (_) => false,
                  onSelecionar: provider.selecionarDia,
                  expandido: _mesAberto,
                  onExpandir: (aberto) => setState(() => _mesAberto = aberto),
                ),
                if (provider.colaboradores.isNotEmpty)
                  FiltroProfissionais(
                    colaboradores: provider.colaboradores,
                    selecionadoId: provider.colaboradorId,
                    onSelecionar: provider.filtrarColaborador,
                  ),
                if (provider.isLoading && provider.carregado)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  const Divider(height: 2),
                if (provider.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      BrandSpacing.space4,
                      BrandSpacing.space2,
                      BrandSpacing.space4,
                      0,
                    ),
                    child: Text(
                      provider.errorMessage!,
                      style: textos.bodyMedium?.copyWith(color: colors.error),
                    ),
                  ),
                Expanded(child: _corpo(provider)),
              ],
            ),
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
        // embaixo, a folga do botão flutuante
        padding: const EdgeInsets.fromLTRB(
          BrandSpacing.space2,
          BrandSpacing.space2,
          BrandSpacing.space2,
          BrandSpacing.space7,
        ),
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

    // a coluna é um painel no fundo 2; o corte acompanha o canto ao rolar
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: BrandSpacing.space1),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: BrandColors.of(context).bg2,
        borderRadius: BrandRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BrandSpacing.space3,
              BrandSpacing.space3,
              BrandSpacing.space3,
              BrandSpacing.space2,
            ),
            child: Row(
              children: [
                // a cor da etapa só marca a coluna; o nome fica em ink
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: cor),
                ),
                const SizedBox(width: BrandSpacing.space2),
                Expanded(
                  child: Text(
                    etapa.nome,
                    style: textos.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${cards.length}', style: textos.bodySmall),
              ],
            ),
          ),
          Expanded(
            child: cards.isEmpty
                ? Center(
                    child: Text(
                      'Nenhum atendimento',
                      style: textos.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: BrandSpacing.space2),
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
