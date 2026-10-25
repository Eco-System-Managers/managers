import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/faixa_semana.dart';

import '../../agenda_provider.dart';
import '../providers/agenda_dia_provider.dart';
import '../widgets/grade_do_dia.dart';
import '../widgets/grade_do_dia_layout.dart';

// a agenda por horário: um dia por vez, com a faixa da semana em cima, o
// filtro por profissional e a grade de horários do expediente. tocar num
// espaço vazio marca naquela hora; ficha e formulário abrem por cima e, ao
// voltar, o dia é recarregado da API
class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key});

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  // a linha do "agora" anda sozinha
  Timer? _relogio;

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
    final provider = ref.watch(agendaDiaProvider);

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final semana = FaixaSemana.diasDaSemana(provider.dia);
        // os meses da semana visível precisam das bolinhas
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) provider.garantirMesesVisiveis(semana);
        });

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
          floatingActionButton: FloatingActionButton(
            onPressed: _novo,
            tooltip: 'Novo agendamento',
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              FaixaSemana(
                dia: provider.dia,
                hoje: provider.hoje,
                temRegistro: provider.temRegistro,
                onSelecionar: provider.selecionarDia,
              ),
              if (provider.colaboradores.isNotEmpty)
                _FiltroColaboradores(provider: provider),
              if (provider.isLoading && provider.carregado)
                const LinearProgressIndicator(minHeight: 2)
              else
                const Divider(height: 2),
              Expanded(child: _corpo(provider)),
            ],
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

    return Column(
      children: [
        if (expediente == null) const _AvisoFechado(),
        Expanded(
          child: intervalo == null
              ? const SizedBox.shrink()
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
                  ),
                ),
        ),
      ],
    );
  }
}

// os chips de profissional: todos, ou um da equipe. o filtro vai para a API
class _FiltroColaboradores extends StatelessWidget {
  const _FiltroColaboradores({required this.provider});

  final AgendaDiaProvider provider;

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

// o negócio não abre neste dia da semana (pelos horários de funcionamento)
class _AvisoFechado extends StatelessWidget {
  const _AvisoFechado();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colors.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pelos horários de funcionamento, o negócio não abre neste dia. '
              'Ainda dá para marcar pelo botão +.',
              style: TextStyle(color: colors.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
