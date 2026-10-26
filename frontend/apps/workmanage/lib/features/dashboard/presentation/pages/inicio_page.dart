import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/features/empresa/empresa_provider.dart';

import '../../dashboard_provider.dart';
import '../providers/resumo_provider.dart';

// a aba Início: os números do período (hoje, por padrão) comparados com o
// anterior, o ranking de serviços e o que vem hoje. o proprietário filtra
// por profissional; quem não é vê só os próprios números, travado pela API
class InicioPage extends ConsumerStatefulWidget {
  const InicioPage({super.key});

  @override
  ConsumerState<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends ConsumerState<InicioPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(resumoProvider).carregar();
    });
  }

  Future<void> _escolherIntervalo(ResumoProvider provider) async {
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
    final provider = ref.watch(resumoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Início')),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          return Column(
            children: [
              if (provider.colaboradores.isNotEmpty)
                _FiltroColaboradores(provider: provider),
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
      ),
    );
  }

  Widget _corpo(ResumoProvider provider) {
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

    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final comparacao = provider.atalho == AtalhoPeriodo.hoje
        ? 'vs. ontem'
        : 'vs. período anterior';
    final ehProprietario = ref.read(negocioAtualProvider).ehProprietario;

    return RefreshIndicator(
      onRefresh: provider.carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // os kpis de dinheiro vêm nulos para o colaborador comum: a tela
          // mostra só o que veio
          _Kpis(
            children: [
              if (resumo.faturamento != null)
                _Kpi(
                  rotulo: 'Faturamento',
                  valor: formatarDinheiro(resumo.faturamento!),
                  variacao: resumo.faturamentoVariacao,
                  comparacao: comparacao,
                  destaque: true,
                ),
              _Kpi(
                rotulo: 'Atendimentos',
                valor: '${resumo.atendimentos}',
                variacao: resumo.atendimentosVariacao,
                comparacao: comparacao,
              ),
              if (resumo.ticketMedio != null)
                _Kpi(
                  rotulo: 'Ticket médio',
                  valor: formatarDinheiro(resumo.ticketMedio!),
                ),
              if (resumo.clientesNovos != null)
                _Kpi(
                  rotulo: 'Clientes novos',
                  valor: '${resumo.clientesNovos}',
                  variacao: resumo.clientesNovosVariacao,
                  comparacao: comparacao,
                ),
              // a comissão: para o dono, o que sai para os parceiros; para
              // o parceiro, o que ele tem a receber
              if (resumo.repasse != null &&
                  (!ehProprietario ||
                      resumo.repasse! > Decimal.zero ||
                      provider.colaboradorId != null))
                _Kpi(
                  rotulo: ehProprietario ? 'Repasse a parceiros' : 'A receber',
                  valor: formatarDinheiro(resumo.repasse!),
                ),
            ],
          ),

          const SizedBox(height: 24),
          Text('Hoje', style: textos.titleMedium),
          const SizedBox(height: 4),
          if (resumo.agendamentosHoje.isEmpty)
            Text(
              resumo.isKanban
                  ? 'Nada em andamento hoje.'
                  : 'Nada marcado para hoje.',
              style: TextStyle(color: colors.onSurfaceVariant),
            )
          else
            for (final a in resumo.agendamentosHoje)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  a.hora,
                  style: textos.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                title: Text(a.clienteNome),
                subtitle: Text(a.servicoNome),
                trailing: const Icon(Icons.chevron_right),
                // no kanban o id é do atendimento da esteira
                onTap: () => context.push(
                  resumo.isKanban ? '/quadro/${a.id}' : '/agenda/${a.id}',
                ),
              ),

          const SizedBox(height: 8),
          // a lista junta os dois modos, então vale também para a esteira
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Pendências de cobrança'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/agenda/pendencias'),
          ),
        ],
      ),
    );
  }
}

// os chips de profissional: todos, ou um da equipe. o filtro vai para a API
class _FiltroColaboradores extends StatelessWidget {
  const _FiltroColaboradores({required this.provider});

  final ResumoProvider provider;

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

// os atalhos de período e o intervalo escolhido
class _Periodos extends StatelessWidget {
  const _Periodos({required this.provider, required this.onPersonalizado});

  final ResumoProvider provider;
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
              for (final (atalho, rotulo) in const [
                (AtalhoPeriodo.hoje, 'Hoje'),
                (AtalhoPeriodo.semana, '7 dias'),
                (AtalhoPeriodo.mes, 'Este mês'),
              ])
                ChoiceChip(
                  label: Text(rotulo),
                  selected: provider.atalho == atalho,
                  onSelected: (_) => provider.selecionarAtalho(atalho),
                ),
              ChoiceChip(
                label: const Text('Período'),
                avatar: const Icon(Icons.date_range, size: 18),
                selected: provider.atalho == AtalhoPeriodo.personalizado,
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

// os cartões em duas colunas, quantos forem
class _Kpis extends StatelessWidget {
  const _Kpis({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largura = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in children) SizedBox(width: largura, child: c),
          ],
        );
      },
    );
  }
}

// um número do período com a variação sobre o anterior
class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.rotulo,
    required this.valor,
    this.variacao,
    this.comparacao = '',
    this.destaque = false,
  });

  final String rotulo;
  final String valor;
  final int? variacao;
  final String comparacao;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final v = variacao;
    final subiu = v != null && v > 0;
    final caiu = v != null && v < 0;
    final corTexto = destaque ? colors.onPrimaryContainer : null;

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
          Text(rotulo, style: textos.bodySmall?.copyWith(color: corTexto)),
          const SizedBox(height: 4),
          Text(
            valor,
            style: textos.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: corTexto,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (v != null) ...[
            const SizedBox(height: 4),
            Text(
              '${v > 0 ? '+' : ''}$v% $comparacao',
              style: textos.bodySmall?.copyWith(
                color: subiu
                    ? Colors.green.shade700
                    : caiu
                    ? colors.error
                    : (corTexto ?? colors.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
