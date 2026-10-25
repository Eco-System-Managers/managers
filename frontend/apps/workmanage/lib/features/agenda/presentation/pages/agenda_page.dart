import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/estado_vazio.dart';
import 'package:managers/core/widgets/faixa_semana.dart';

import '../../agenda_provider.dart';
import '../providers/agenda_dia_provider.dart';
import '../widgets/agendamento_card.dart';

// a agenda por horário: um dia por vez, com a faixa da semana em cima. ficha
// e formulário abrem por cima; ao voltar, o dia é recarregado da API
class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key});

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  AgendaDiaProvider get _provider => ref.read(agendaDiaProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
  }

  // a tela aberta pode ter criado, remarcado ou cancelado: o dia e as
  // bolinhas vêm da API de novo
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
              if (provider.colaboradores.isNotEmpty)
                _FiltroColaborador(provider: provider),
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
            onPressed: () =>
                _abrir('/agenda/novo?data=${dataParaApi(provider.dia)}'),
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

    if (provider.agendamentos.isEmpty) {
      return EstadoVazio(
        icone: Icons.event_available_outlined,
        titulo: provider.ehHoje
            ? 'Nada marcado para hoje'
            : 'Nada marcado em ${formatarDataPorExtenso(provider.dia)}',
        mensagem: provider.colaboradorId != null
            ? 'Este profissional não tem horário neste dia.'
            : 'Toque em + para marcar um horário.',
      );
    }

    return RefreshIndicator(
      onRefresh: provider.recarregar,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: provider.agendamentos.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final agendamento = provider.agendamentos[index];
          return AgendamentoCard(
            agendamento: agendamento,
            onTap: () => _abrir('/agenda/${agendamento.id}'),
          );
        },
      ),
    );
  }
}

// o filtro por profissional: todos, ou um da equipe
class _FiltroColaborador extends StatelessWidget {
  const _FiltroColaborador({required this.provider});

  final AgendaDiaProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ativo = provider.colaboradorId != null;

    return PopupMenuButton<int>(
      tooltip: 'Filtrar por profissional',
      icon: Icon(
        ativo ? Icons.person : Icons.person_outline,
        color: ativo ? colors.primary : null,
      ),
      // 0 é "todos": os ids da equipe começam em 1
      onSelected: (id) => provider.filtrarColaborador(id == 0 ? null : id),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: 0,
          checked: !ativo,
          child: const Text('Todos'),
        ),
        for (final c in provider.colaboradores)
          CheckedPopupMenuItem(
            value: c.id,
            checked: provider.colaboradorId == c.id,
            child: Text(c.nome),
          ),
      ],
    );
  }
}
