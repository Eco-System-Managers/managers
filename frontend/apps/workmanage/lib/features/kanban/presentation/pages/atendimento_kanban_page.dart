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
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:managers/features/financeiro/domain/entities/pagamento.dart';
import 'package:managers/features/financeiro/presentation/widgets/cobranca_sheet.dart';

import '../../domain/entities/atendimento_kanban.dart';
import '../../kanban_provider.dart';
import '../providers/atendimento_kanban_provider.dart';
import '../widgets/cor_da_etapa.dart';

// a ficha de um card da esteira e as ações sobre ele: mover de etapa,
// cobrar e desfazer, marcar falta e desfazer, excluir
class AtendimentoKanbanPage extends ConsumerStatefulWidget {
  const AtendimentoKanbanPage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<AtendimentoKanbanPage> createState() =>
      _AtendimentoKanbanPageState();
}

class _AtendimentoKanbanPageState extends ConsumerState<AtendimentoKanbanPage> {
  AtendimentoKanbanProvider get _provider =>
      ref.read(atendimentoKanbanProvider(widget.id));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _cobrar(AtendimentoKanban a) async {
    final cobrou = await CobrancaSheet.abrir(
      context,
      atendimentoId: a.id,
      valorServicos: a.servicoPreco,
      creditoDisponivel: _provider.saldo?.saldo ?? Decimal.fromInt(0),
      onCobrar: (params) async {
        final ok = await _provider.cobrar(params);
        return ok ? null : _provider.errorMessage;
      },
    );
    if (cobrou && mounted) {
      _provider.limparErro();
      _avisar('Cobrança registrada.');
    }
  }

  Future<void> _desfazerCobranca() async {
    final ok = await confirmar(
      context,
      titulo: 'Desfazer cobrança',
      mensagem: 'Os pagamentos saem do caixa e o crédito gerado é estornado.',
      textoConfirmar: 'Desfazer',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    await _provider.desfazerCobranca();
  }

  Future<void> _marcarFalta(AtendimentoKanban a) async {
    final ok = await confirmar(
      context,
      titulo: 'Marcar falta',
      mensagem:
          '${a.clienteNome} não veio? O atendimento fica registrado '
          'como falta.',
      textoConfirmar: 'Marcar falta',
    );
    if (!ok || !mounted) return;
    await _provider.alterarFalta(true);
  }

  Future<void> _excluir(AtendimentoKanban a) async {
    final ok = await confirmar(
      context,
      titulo: 'Excluir atendimento',
      mensagem:
          'O atendimento de ${a.clienteNome} sai do quadro de vez. Use '
          'para registro feito por engano.',
      textoConfirmar: 'Excluir',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    await _provider.remover();
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(atendimentoKanbanProvider(widget.id));

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        if (provider.removido) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop(true);
          });
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Atendimento')),
          body: _corpo(context, provider),
        );
      },
    );
  }

  Widget _corpo(BuildContext context, AtendimentoKanbanProvider provider) {
    final a = provider.atendimento;
    if (a == null) {
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
    final etapaAtual = provider.etapas
        .where((e) => e.id == a.etapaId)
        .firstOrNull;
    final cor = corDaEtapa(etapaAtual?.cor ?? '', colors);
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
                      a.horarioEntrada == null
                          ? 'Sem hora marcada'
                          : formatarHora(a.horarioEntrada!),
                      style: textos.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a.data == null ? '' : formatarDataPorExtenso(a.data!),
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        Chip(
                          avatar: CircleAvatar(backgroundColor: cor, radius: 6),
                          label: Text(a.etapaNome),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (a.pago)
                          Chip(
                            avatar: Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: Colors.green.shade700,
                            ),
                            label: const Text('Pago'),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (a.faltou)
                          Chip(
                            avatar: Icon(
                              Icons.person_off_outlined,
                              size: 16,
                              color: colors.error,
                            ),
                            label: const Text('Faltou'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
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
                leading: Icon(
                  a.objeto.veiculo != null
                      ? Icons.directions_car_outlined
                      : Icons.pets,
                ),
                title: Text(a.objeto.titulo),
                subtitle: a.objeto.detalhe.isEmpty
                    ? null
                    : Text(a.objeto.detalhe),
              ),
              const Divider(),
              if (a.colaboradorNome.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(a.colaboradorNome),
                  subtitle: const Text('Profissional'),
                ),
              ListTile(
                leading: const Icon(Icons.design_services_outlined),
                title: Text(a.servicoNome),
                subtitle: a.servicoDuracao > 0
                    ? Text('${a.servicoDuracao} min')
                    : null,
                trailing: Text(formatarDinheiro(a.servicoPreco)),
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
              if (a.observacao.isNotEmpty) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.notes_outlined),
                  title: const Text('Observação'),
                  subtitle: Text(a.observacao),
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

  Widget _acoes(AtendimentoKanban a, AtendimentoKanbanProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final ocupado = provider.isLoading;
    final outras = provider.etapas.where((e) => e.id != a.etapaId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (outras.isNotEmpty) ...[
          Text('Mover para', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in outras)
                ActionChip(
                  avatar: CircleAvatar(
                    backgroundColor: corDaEtapa(e.cor, colors),
                    radius: 6,
                  ),
                  label: Text(e.nome),
                  onPressed: ocupado ? null : () => provider.mover(e.id),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        // o colaborador comum só cobra com a flag ligada (a API recusa com
        // sem_permissao_cobrar)
        if (ref.read(negocioAtualProvider).podeCobrar) ...[
          if (!a.pago)
            FilledButton.icon(
              onPressed: ocupado ? null : () => _cobrar(a),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.point_of_sale_outlined),
              label: const Text('Cobrar'),
            )
          else
            OutlinedButton.icon(
              onPressed: ocupado ? null : _desfazerCobranca,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.undo),
              label: const Text('Desfazer cobrança'),
            ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: a.faltou
                  ? TextButton.icon(
                      onPressed: ocupado
                          ? null
                          : () => provider.alterarFalta(false),
                      icon: const Icon(Icons.undo),
                      label: const Text('Desfazer falta'),
                    )
                  : TextButton.icon(
                      // a API recusa falta em atendimento pago (falta_em_pago)
                      onPressed: ocupado || a.pago
                          ? null
                          : () => _marcarFalta(a),
                      icon: const Icon(Icons.person_off_outlined),
                      label: const Text('Faltou'),
                    ),
            ),
            if (!a.pago)
              Expanded(
                child: TextButton.icon(
                  onPressed: ocupado ? null : () => _excluir(a),
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
