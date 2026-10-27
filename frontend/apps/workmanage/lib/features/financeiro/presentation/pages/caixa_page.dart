import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/avatar_iniciais.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/filtros.dart';
import 'package:managers/core/widgets/folha.dart';
import 'package:managers/core/widgets/painel.dart';

import '../../domain/entities/caixa.dart';
import '../../financeiro_provider.dart';
import '../providers/caixa_provider.dart';

// Mais › Caixa: o fechamento de um período, na linguagem do Início (chips
// de filtro, painéis neutros, um número grande) mas com a cara de caixa: o
// que entrou, como entrou (por forma de pagamento) e para onde vai (casa e
// parceiros), e cada pagamento agrupado por dia. filtro por profissional
// para o dono; o parceiro vê só a parte dele (casa vem nula)
class CaixaPage extends ConsumerStatefulWidget {
  const CaixaPage({super.key});

  @override
  ConsumerState<CaixaPage> createState() => _CaixaPageState();
}

class _CaixaPageState extends ConsumerState<CaixaPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(caixaProvider).carregar();
    });
  }

  Future<void> _escolherPeriodo(CaixaProvider provider) async {
    final escolha = await escolherNaFolha<PeriodoCaixa>(
      context,
      titulo: 'Período',
      opcoes: [
        for (final (periodo, rotulo) in const [
          (PeriodoCaixa.hoje, 'Hoje'),
          (PeriodoCaixa.semana, 'Últimos 7 dias'),
          (PeriodoCaixa.mes, 'Este mês'),
          (PeriodoCaixa.personalizado, 'Escolher as datas'),
        ])
          OpcaoDaFolha(
            valor: periodo,
            texto: rotulo,
            selecionada: provider.periodo == periodo,
            icone: periodo == PeriodoCaixa.personalizado
                ? Icons.date_range_outlined
                : null,
          ),
      ],
    );
    if (escolha == null || !mounted) return;
    if (escolha != PeriodoCaixa.personalizado) {
      provider.selecionarPeriodo(escolha);
      return;
    }
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

  Future<void> _escolherProfissional(CaixaProvider provider) async {
    // o id, ou 0 para todos (null fecharia sem escolher)
    final escolha = await escolherNaFolha<int>(
      context,
      titulo: 'Profissional',
      opcoes: [
        OpcaoDaFolha(
          valor: 0,
          texto: 'Todos',
          selecionada: provider.colaboradorId == null,
          icone: Icons.groups_outlined,
        ),
        for (final c in provider.colaboradores)
          OpcaoDaFolha(
            valor: c.id,
            texto: c.nome,
            selecionada: provider.colaboradorId == c.id,
            avatar: AvatarIniciais(nome: c.nome, raio: 16),
          ),
      ],
    );
    if (escolha == null || !mounted) return;
    provider.filtrarColaborador(escolha == 0 ? null : escolha);
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(caixaProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Financeiro')),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          return Column(
            children: [
              _Filtros(
                provider: provider,
                onPeriodo: () => _escolherPeriodo(provider),
                onProfissional: provider.colaboradores.isEmpty
                    ? null
                    : () => _escolherProfissional(provider),
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
    final vazio = caixa.pagamentos.isEmpty;
    // só o dono vê a divisão; o parceiro vê a parte dele como "a receber"
    final temDivisao = caixa.casa != null && caixa.repasse > Decimal.zero;
    final porDia = _agruparPorDia(caixa.pagamentos);

    return RefreshIndicator(
      onRefresh: provider.carregar,
      child: ListView(
        padding: paddingDaPagina(
          context,
          topo: 8,
        ).copyWith(left: 16, right: 16),
        children: [
          // ---- o que entrou ----
          Painel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recebido ${_rotuloDoPeriodo(provider)}',
                  style: textos.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatarDinheiro(caixa.total),
                  style: textos.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  vazio
                      ? 'Nenhuma cobrança no período.'
                      : '${caixa.atendimentos} '
                            '${caixa.atendimentos == 1 ? 'atendimento' : 'atendimentos'}'
                            ' · ticket médio ${formatarDinheiro(caixa.ticketMedio)}',
                  style: textos.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),

                // para onde vai: a casa e os parceiros, numa barra dividida
                if (temDivisao) ...[
                  const SizedBox(height: 16),
                  _Divisao(casa: caixa.casa!, repasse: caixa.repasse),
                ] else if (caixa.casa == null) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Sua parte a receber',
                          style: textos.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        formatarDinheiro(caixa.repasse),
                        style: textos.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ---- como entrou ----
          if (caixa.porForma.isNotEmpty) ...[
            const SizedBox(height: 24),
            const TituloDaSecao('Por forma de pagamento'),
            const SizedBox(height: 12),
            Painel(
              child: Column(
                children: [
                  for (final (i, f) in caixa.porForma.indexed) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _LinhaDaForma(forma: f),
                  ],
                ],
              ),
            ),
          ],

          // ---- cada pagamento, por dia ----
          const SizedBox(height: 24),
          TituloDaSecao(
            'Pagamentos',
            detalhe: vazio ? null : '${caixa.pagamentos.length}',
          ),
          const SizedBox(height: 12),
          if (vazio)
            Painel(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: colors.secondaryContainer,
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Caixa vazio',
                          style: textos.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'As cobranças feitas na agenda e no quadro '
                          'aparecem aqui.',
                          style: textos.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            for (final (i, dia) in porDia.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              _DiaDoCaixa(dia: dia, mostraData: porDia.length > 1),
            ],
        ],
      ),
    );
  }

  String _rotuloDoPeriodo(CaixaProvider provider) {
    switch (provider.periodo) {
      case PeriodoCaixa.hoje:
        return 'hoje';
      case PeriodoCaixa.semana:
        return 'nos últimos 7 dias';
      case PeriodoCaixa.mes:
        return 'este mês';
      case PeriodoCaixa.personalizado:
        return mesmoDia(provider.inicio, provider.fim)
            ? 'em ${formatarData(provider.inicio)}'
            : 'de ${formatarData(provider.inicio)} a '
                  '${formatarData(provider.fim)}';
    }
  }

  // do mais recente para o mais antigo, cada dia com o seu total
  static List<_DiaComPagamentos> _agruparPorDia(List<CaixaPagamento> lista) {
    final ordenada = [...lista]
      ..sort((a, b) => b.dataHora.compareTo(a.dataHora));
    final dias = <_DiaComPagamentos>[];
    for (final p in ordenada) {
      final data = somenteData(p.dataHora.toLocal());
      if (dias.isEmpty || !mesmoDia(dias.last.data, data)) {
        dias.add(_DiaComPagamentos(data: data, pagamentos: []));
      }
      dias.last.pagamentos.add(p);
    }
    return dias;
  }
}

class _DiaComPagamentos {
  _DiaComPagamentos({required this.data, required this.pagamentos});

  final DateTime data;
  final List<CaixaPagamento> pagamentos;

  Decimal get total =>
      pagamentos.fold(Decimal.zero, (soma, p) => soma + p.valor);
}

// os dois filtros, com o mesmo desenho do Início
class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.provider,
    required this.onPeriodo,
    this.onProfissional,
  });

  final CaixaProvider provider;
  final VoidCallback onPeriodo;
  final VoidCallback? onProfissional;

  @override
  Widget build(BuildContext context) {
    final periodo = switch (provider.periodo) {
      PeriodoCaixa.hoje => 'Hoje',
      PeriodoCaixa.semana => '7 dias',
      PeriodoCaixa.mes => 'Este mês',
      PeriodoCaixa.personalizado =>
        mesmoDia(provider.inicio, provider.fim)
            ? formatarData(provider.inicio)
            : '${provider.inicio.day}/${provider.inicio.month} a '
                  '${provider.fim.day}/${provider.fim.month}',
    };
    final escolhido = provider.colaboradores
        .where((c) => c.id == provider.colaboradorId)
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          ChipDeFiltro(
            icone: Icons.calendar_today_outlined,
            texto: periodo,
            onTap: onPeriodo,
          ),
          if (onProfissional != null) ...[
            const SizedBox(width: 8),
            ChipDeFiltro(
              icone: Icons.person_outline,
              texto: escolhido == null ? 'Todos' : primeiroNome(escolhido.nome),
              onTap: onProfissional!,
            ),
          ],
        ],
      ),
    );
  }
}

// a divisão do recebido: a casa na primária, os parceiros num tom claro,
// numa barra só, com os dois valores embaixo
class _Divisao extends StatelessWidget {
  const _Divisao({required this.casa, required this.repasse});

  final Decimal casa;
  final Decimal repasse;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final total = casa + repasse;
    final fracaoCasa = total == Decimal.zero
        ? 1.0
        : (casa / total).toDouble().clamp(0.0, 1.0);
    final corCasa = colors.primary;
    final corRepasse = colors.primary.withValues(alpha: 0.28);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                // flex nunca zero: uma parte vazia some sem quebrar a Row
                Expanded(
                  flex: (fracaoCasa * 1000).round().clamp(1, 1000),
                  child: ColoredBox(color: corCasa),
                ),
                // um fio de superfície entre as duas partes
                const SizedBox(width: 2),
                Expanded(
                  flex: ((1 - fracaoCasa) * 1000).round().clamp(1, 1000),
                  child: ColoredBox(color: corRepasse),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Legenda(
                cor: corCasa,
                rotulo: 'Fica para a casa',
                valor: formatarDinheiro(casa),
              ),
            ),
            Expanded(
              child: _Legenda(
                cor: corRepasse,
                rotulo: 'Repasse a parceiros',
                valor: formatarDinheiro(repasse),
                aDireita: true,
              ),
            ),
          ],
        ),
        if (total > Decimal.zero)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${(fracaoCasa * 100).round()}% da casa',
              style: textos.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda({
    required this.cor,
    required this.rotulo,
    required this.valor,
    this.aDireita = false,
  });

  final Color cor;
  final String rotulo;
  final String valor;
  final bool aDireita;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final alinhamento = aDireita
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alinhamento,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: cor),
            ),
            const SizedBox(width: 6),
            Text(
              rotulo,
              style: textos.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Text(
          valor,
          style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// uma forma de pagamento: ícone, nome, a barra da fatia, o percentual e o
// valor
class _LinhaDaForma extends StatelessWidget {
  const _LinhaDaForma({required this.forma});

  final CaixaPorForma forma;

  static IconData _icone(String forma) => switch (forma) {
    'dinheiro' => Icons.payments_outlined,
    'pix' => Icons.bolt_outlined,
    'credito' || 'debito' => Icons.credit_card_outlined,
    'qr_code' => Icons.qr_code_2_outlined,
    _ => Icons.paid_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(_icone(forma.forma), size: 20, color: colors.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Text(
            nomeDaForma(forma.forma),
            style: textos.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: forma.percentual / 100,
              minHeight: 8,
              backgroundColor: colors.surfaceContainerHighest,
              color: colors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 34,
          child: Text(
            '${forma.percentual}%',
            textAlign: TextAlign.right,
            style: textos.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 84,
          child: Text(
            formatarDinheiro(forma.total),
            textAlign: TextAlign.right,
            style: textos.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// um dia do caixa: a data e o total do dia em cima, cada pagamento embaixo
class _DiaDoCaixa extends StatelessWidget {
  const _DiaDoCaixa({required this.dia, required this.mostraData});

  final _DiaComPagamentos dia;

  // num período de um dia só a data é redundante
  final bool mostraData;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Painel(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mostraData) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatarDataPorExtenso(dia.data),
                    style: textos.labelLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  formatarDinheiro(dia.total),
                  style: textos.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
          ],
          for (final (i, p) in dia.pagamentos.indexed) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.4),
              ),
            _LinhaDoPagamento(pagamento: p),
          ],
        ],
      ),
    );
  }
}

class _LinhaDoPagamento extends StatelessWidget {
  const _LinhaDoPagamento({required this.pagamento});

  final CaixaPagamento pagamento;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final p = pagamento;
    final hora = p.dataHora.toLocal();
    final detalhe = [
      if (p.servicoNome.isNotEmpty) p.servicoNome,
      if (p.colaboradorNome.isNotEmpty) p.colaboradorNome,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              formatarHora((hora: hora.hour, minuto: hora.minute)),
              style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.clienteNome,
                  style: textos.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (detalhe.isNotEmpty)
                  Text(
                    detalhe,
                    style: textos.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatarDinheiro(p.valor),
                style: textos.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                nomeDaForma(p.forma),
                style: textos.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
