import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/mascara_formatter.dart';

import '../../agenda_provider.dart';
import '../../domain/entities/agendamento.dart';
import '../providers/agendamento_provider.dart';
import '../widgets/cobranca_sheet.dart';
import '../widgets/remarcar_sheet.dart';
import '../widgets/status_agendamento_chip.dart';

// a ficha de um agendamento e as ações sobre ele: confirmar, cobrar,
// remarcar, marcar falta e cancelar. o que cabe depende do status
class AgendamentoPage extends ConsumerStatefulWidget {
  const AgendamentoPage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<AgendamentoPage> createState() => _AgendamentoPageState();
}

class _AgendamentoPageState extends ConsumerState<AgendamentoPage> {
  AgendamentoProvider get _provider => ref.read(agendamentoProvider(widget.id));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
  }

  Future<void> _cobrar(Agendamento agendamento) async {
    final cobrou = await CobrancaSheet.abrir(
      context,
      agendamento: agendamento,
      creditoDisponivel: _provider.saldo?.saldo ?? Decimal.fromInt(0),
      onCobrar: (params) async {
        final ok = await _provider.cobrar(params);
        return ok ? null : _provider.errorMessage;
      },
    );
    if (cobrou && mounted) {
      // o erro da folha já foi mostrado lá; a ficha não repete
      _provider.limparErro();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cobrança registrada.')));
    }
  }

  Future<void> _remarcar(Agendamento agendamento) async {
    final novaDataHora = await RemarcarSheet.abrir(
      context,
      dataHoraAtual: agendamento.dataHora,
      temGrade:
          agendamento.colaboradorId != null && agendamento.servicos.isNotEmpty,
      buscarSlots: _provider.slotsParaRemarcar,
    );
    if (novaDataHora == null || !mounted) return;
    await _provider.remarcar(novaDataHora);
  }

  Future<void> _marcarFalta(Agendamento agendamento) async {
    final ok = await confirmar(
      context,
      titulo: 'Marcar falta',
      mensagem:
          '${agendamento.clienteNome} não veio? O horário fica '
          'registrado como falta.',
      textoConfirmar: 'Marcar falta',
    );
    if (!ok || !mounted) return;
    await _provider.alterarStatus(StatusAgendamento.faltou);
  }

  Future<void> _cancelar(Agendamento agendamento) async {
    final ok = await confirmar(
      context,
      titulo: 'Cancelar agendamento',
      mensagem:
          'O horário de ${agendamento.clienteNome} é liberado. Se o '
          'cliente marcou pelo app, ele é avisado.',
      textoConfirmar: 'Cancelar agendamento',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    await _provider.cancelar();
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(agendamentoProvider(widget.id));

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        if (provider.cancelado) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop(true);
          });
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Agendamento')),
          body: _corpo(context, provider),
        );
      },
    );
  }

  Widget _corpo(BuildContext context, AgendamentoProvider provider) {
    final agendamento = provider.agendamento;
    if (agendamento == null) {
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
    final a = agendamento;
    final telefone = MascaraFormatter.dinamica(MascaraFormatter.telefone)
        .aplicar(a.clienteTelefone);

    return Column(
      children: [
        if (provider.isLoading)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      '${formatarHora(horaDe(a.dataHora))} – '
                      '${formatarHora(horaDe(a.fim))}',
                      style: textos.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatarDataPorExtenso(a.dataHora),
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    StatusAgendamentoChip(status: a.status),
                  ],
                ),
              ),

              if (provider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      provider.errorMessage!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ),

              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(a.clienteNome),
                subtitle: telefone.isEmpty ? null : Text(telefone),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/clientes/${a.clienteId}'),
              ),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(
                  (a.colaboradorNome?.isNotEmpty ?? false)
                      ? a.colaboradorNome!
                      : 'Sem profissional definido',
                ),
                subtitle: const Text('Profissional'),
              ),
              const Divider(),

              for (final s in a.servicos)
                ListTile(
                  leading: const Icon(Icons.design_services_outlined),
                  title: Text(s.nome),
                  subtitle: Text('${s.duracao} min'),
                  trailing: Text(formatarDinheiro(s.precoCobrado - s.desconto)),
                ),
              if (a.desconto > Decimal.fromInt(0))
                ListTile(
                  leading: const Icon(Icons.discount_outlined),
                  title: const Text('Desconto'),
                  trailing: Text('- ${formatarDinheiro(a.desconto)}'),
                ),
              ListTile(
                title: Text(
                  'Total',
                  style: textos.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Text(
                  formatarDinheiro(a.valorTotal),
                  style: textos.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              if (a.pagamentos.isNotEmpty) ...[
                const Divider(),
                for (final p in a.pagamentos)
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(p.forma.nome),
                    subtitle: const Text('Pago'),
                    trailing: Text(formatarDinheiro(p.valor)),
                  ),
              ],

              if (a.observacoes.isNotEmpty) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.notes_outlined),
                  title: const Text('Observações'),
                  subtitle: Text(a.observacoes),
                ),
              ],

              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _acoes(a, provider),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // o que dá para fazer em cada status
  Widget _acoes(Agendamento a, AgendamentoProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final ocupado = provider.isLoading;

    if (a.status == StatusAgendamento.concluido ||
        a.status == StatusAgendamento.cancelado) {
      return const SizedBox.shrink();
    }

    if (a.status == StatusAgendamento.faltou) {
      return OutlinedButton.icon(
        onPressed: ocupado
            ? null
            : () => provider.alterarStatus(StatusAgendamento.agendado),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        icon: const Icon(Icons.undo),
        label: const Text('Desfazer falta'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: ocupado ? null : () => _cobrar(a),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.point_of_sale_outlined),
          label: const Text('Cobrar'),
        ),
        const SizedBox(height: 12),
        if (a.status == StatusAgendamento.agendado) ...[
          FilledButton.tonalIcon(
            onPressed: ocupado
                ? null
                : () => provider.alterarStatus(StatusAgendamento.confirmado),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.thumb_up_alt_outlined),
            label: const Text('Confirmar'),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: ocupado ? null : () => _remarcar(a),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          icon: const Icon(Icons.event_repeat_outlined),
          label: const Text('Remarcar'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: ocupado ? null : () => _marcarFalta(a),
                icon: const Icon(Icons.person_off_outlined),
                label: const Text('Faltou'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: ocupado ? null : () => _cancelar(a),
                style: TextButton.styleFrom(foregroundColor: colors.error),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
