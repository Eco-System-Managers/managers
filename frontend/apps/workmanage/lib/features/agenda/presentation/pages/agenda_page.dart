import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/faixa_semana.dart';
import 'package:managers/core/widgets/sombra_de_borda.dart';
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:managers/features/usuarios/presentation/widgets/filtro_profissionais.dart';

import '../../agenda_provider.dart';
import '../../domain/entities/bloqueio.dart';
import '../providers/agenda_dia_provider.dart';
import '../widgets/bloqueio_sheet.dart';
import '../widgets/grade_do_dia.dart';
import '../widgets/grade_do_dia_layout.dart';

// a agenda por horário: um dia por vez, com o calendário em cima (a semana,
// ou o mês quando aberto pelo título ou pela alça), o filtro por
// profissional e a grade de horários do expediente. deslizar a grade para o
// lado troca o dia. tocar num espaço vazio marca naquela hora; tocar num
// bloqueio abre a ficha dele. ficha e formulário abrem por cima e, ao
// voltar, o dia é recarregado da API
class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key});

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  // a linha do "agora" anda sozinha
  Timer? _relogio;

  // o mês inteiro aberto em cima da grade
  bool _mesAberto = false;

  // para que lado a grade entra quando o dia muda (deslizar ou tocar)
  bool _avancou = true;

  AgendaDiaProvider get _provider => ref.read(agendaDiaProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
    _relogio = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  // a tela aberta pode ter criado, remarcado ou cancelado: o dia e as
  // bolinhas vêm da API de novo
  Future<void> _abrir(String rota) async {
    await context.push(rota);
    if (mounted) _provider.recarregar();
  }

  void _novo({Hora? hora}) {
    final provider = _provider;
    final partes = [
      'data=${dataParaApi(provider.dia)}',
      if (hora != null) 'hora=${horaParaApi(hora)}',
      if (provider.colaboradorId != null)
        'colaborador=${provider.colaboradorId}',
    ];
    _abrir('/agenda/novo?${partes.join('&')}');
  }

  // o dia e o profissional abertos vêm preenchidos no bloqueio
  void _bloquear() {
    final provider = _provider;
    final partes = [
      'data=${dataParaApi(provider.dia)}',
      if (provider.colaboradorId != null)
        'colaborador=${provider.colaboradorId}',
    ];
    _abrir('/agenda/bloquear?${partes.join('&')}');
  }

  void _abrirBloqueio(Bloqueio bloqueio) {
    final podeExcluir = ref
        .read(negocioAtualProvider)
        .podeBloquearAgendaDe(bloqueio.colaboradorId);
    BloqueioSheet.abrir(
      context,
      bloqueio: bloqueio,
      excluir: podeExcluir
          ? () => _provider.excluirBloqueio(bloqueio.id)
          : null,
    );
  }

  void _selecionarDia(DateTime dia) {
    _avancou = !dia.isBefore(_provider.dia);
    _provider.selecionarDia(dia);
  }

  // deslizar a grade para a esquerda avança um dia; para a direita volta
  void _deslizouGrade(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 250) return;
    final dia = _provider.dia;
    _selecionarDia(DateTime(dia.year, dia.month, dia.day + (v < 0 ? 1 : -1)));
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a aba estiver aberta
    final provider = ref.watch(agendaDiaProvider);

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        // os meses na tela (a semana pode cruzar dois) precisam das bolinhas
        final visiveis = _mesAberto
            ? FaixaSemana.diasDoMes(provider.dia)
            : FaixaSemana.diasDaSemana(provider.dia);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) provider.garantirMesesVisiveis(visiveis);
        });
        final cores = BrandColors.of(context);

        return Scaffold(
          appBar: AppBar(
            // o dia por extenso; com o mês aberto, o mês. tocar abre e fecha
            title: _TituloDoDia(
              dia: provider.dia,
              mesAberto: _mesAberto,
              onTap: () => setState(() => _mesAberto = !_mesAberto),
            ),
            actions: [
              if (ref.read(negocioAtualProvider).podeBloquear)
                IconButton(
                  tooltip: 'Bloquear horário',
                  onPressed: _bloquear,
                  icon: const Icon(Icons.event_busy_rounded),
                ),
              if (!provider.ehHoje)
                TextButton(
                  onPressed: () => _selecionarDia(provider.hoje),
                  child: const Text('Hoje'),
                ),
              IconButton(
                tooltip: 'Cobranças pendentes',
                onPressed: () => _abrir('/agenda/pendencias'),
                // pendente é atenção: o contador em warning, como a lista de
                // pendências e o Início (o badge do tema é danger)
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
          floatingActionButton: FloatingActionButton(
            onPressed: _novo,
            tooltip: 'Novo agendamento',
            child: const Icon(Icons.add_rounded),
          ),
          body: comSombraEmBaixo(
            Column(
              children: [
                FaixaSemana(
                  dia: provider.dia,
                  hoje: provider.hoje,
                  temRegistro: provider.temRegistro,
                  onSelecionar: _selecionarDia,
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
                Expanded(child: _corpo(provider)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _corpo(AgendaDiaProvider provider) {
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

    final expediente = provider.expedienteDoDia;
    final blocos = distribuirColunas(provider.agendamentos);
    final intervalo = intervaloDaGrade(expediente: expediente, blocos: blocos);

    return GestureDetector(
      onHorizontalDragEnd: _deslizouGrade,
      child: Column(
        children: [
          if (expediente == null)
            const _AvisoFechado()
          else if (provider.agendamentos.isEmpty)
            const _DiaLivre(),
          Expanded(
            // o dia novo entra deslizando do lado para onde a pessoa foi
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final entrando = child.key == ValueKey(provider.dia);
                final de = Offset((entrando == _avancou) ? 0.15 : -0.15, 0);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: de,
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(provider.dia),
                child: intervalo == null
                    ? const SizedBox.expand()
                    : RefreshIndicator(
                        onRefresh: provider.recarregar,
                        child: GradeDoDia(
                          inicio: intervalo.inicio,
                          fim: intervalo.fim,
                          passo: provider.passoMinutos,
                          blocos: blocos,
                          agora: provider.ehHoje ? DateTime.now() : null,
                          onTapVazio: (hora) => _novo(hora: hora),
                          onTapAgendamento: (a) => _abrir('/agenda/${a.id}'),
                          faixas: faixasDosBloqueios(provider.bloqueios),
                          onTapBloqueio: _abrirBloqueio,
                          nomeNoBloqueio: provider.colaboradorId == null,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// o título da barra: "ter, 27 de outubro" (com o ano quando não é o atual)
// ou, com o mês aberto, "outubro de 2026". a seta vira quando abre
class _TituloDoDia extends StatelessWidget {
  const _TituloDoDia({
    required this.dia,
    required this.mesAberto,
    required this.onTap,
  });

  final DateTime dia;
  final bool mesAberto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esteAno = dia.year == DateTime.now().year;
    final texto = mesAberto
        ? formatarMesAno(dia)
        : esteAno
        ? formatarDataPorExtenso(dia)
        : '${formatarDataPorExtenso(dia)} de ${dia.year}';

    return InkWell(
      onTap: onTap,
      borderRadius: BrandRadius.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BrandSpacing.space1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
            AnimatedRotation(
              turns: mesAberto ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.arrow_drop_down_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

// nada marcado no dia aberto
class _DiaLivre extends StatelessWidget {
  const _DiaLivre();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BrandSpacing.space4,
        BrandSpacing.space2,
        BrandSpacing.space4,
        BrandSpacing.space1,
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: BrandSpacing.space2),
          Expanded(
            child: Text(
              'Dia livre. Toque num horário para marcar.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// o negócio não abre neste dia da semana (pelos horários de funcionamento)
class _AvisoFechado extends StatelessWidget {
  const _AvisoFechado();

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        BrandSpacing.space4,
        BrandSpacing.space3,
        BrandSpacing.space4,
        BrandSpacing.space1,
      ),
      padding: const EdgeInsets.all(BrandSpacing.space3),
      decoration: BoxDecoration(
        color: cores.bg2,
        borderRadius: BrandRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: cores.inkMuted),
          const SizedBox(width: BrandSpacing.space3),
          Expanded(
            child: Text(
              'Pelos horários de funcionamento, o negócio não abre neste dia. '
              'Ainda dá para marcar pelo botão +.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
