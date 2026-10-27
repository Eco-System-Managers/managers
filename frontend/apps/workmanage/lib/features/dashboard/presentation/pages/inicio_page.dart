import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/compartilhar/whatsapp.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/avatar_iniciais.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/filtros.dart';
import 'package:managers/core/widgets/painel.dart';
import 'package:managers/core/widgets/sombra_de_borda.dart';
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:managers/features/empresa/presentation/providers/negocio_atual_provider.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';

import '../../dashboard_provider.dart';
import '../../domain/entities/dashboard_resumo.dart';
import '../../domain/proximo_de_hoje.dart';
import '../providers/resumo_provider.dart';
import '../widgets/grafico_barras.dart';

// a aba Início: o que vem agora primeiro (o próximo atendimento e a linha
// do dia), os números do período depois, em tom mais baixo. o período e o
// profissional são dois chips iguais que abrem uma folha. o proprietário
// filtra por profissional; quem não é vê só os próprios números, travado
// pela API
class InicioPage extends ConsumerStatefulWidget {
  const InicioPage({super.key});

  @override
  ConsumerState<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends ConsumerState<InicioPage> {
  // a contagem para o próximo ("em 25 min") anda sozinha
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(resumoProvider).carregar();
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

  // a ficha pode ter cobrado ou cancelado: os números vêm de novo
  Future<void> _abrir(String rota) async {
    await context.push(rota);
    if (mounted) ref.read(resumoProvider).carregar();
  }

  Future<void> _escolherPeriodo(ResumoProvider provider) async {
    final escolha = await escolherNaFolha<AtalhoPeriodo>(
      context,
      titulo: 'Período',
      opcoes: [
        for (final (atalho, rotulo) in const [
          (AtalhoPeriodo.hoje, 'Hoje'),
          (AtalhoPeriodo.semana, 'Últimos 7 dias'),
          (AtalhoPeriodo.mes, 'Este mês'),
          (AtalhoPeriodo.personalizado, 'Escolher as datas'),
        ])
          OpcaoDaFolha(
            valor: atalho,
            texto: rotulo,
            selecionada: provider.atalho == atalho,
            icone: atalho == AtalhoPeriodo.personalizado
                ? Icons.date_range_outlined
                : null,
          ),
      ],
    );
    if (escolha == null || !mounted) return;
    if (escolha != AtalhoPeriodo.personalizado) {
      provider.selecionarAtalho(escolha);
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

  Future<void> _escolherProfissional(ResumoProvider provider) async {
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

  Future<void> _whatsApp(AgendamentoHoje a) async {
    final negocio = ref.read(negocioAtualProvider).nome;
    final texto =
        'Oi, ${primeiroNome(a.clienteNome)}! '
        '${negocio.isEmpty ? 'Aqui é do seu horário' : 'Aqui é do $negocio'}: '
        'te esperamos hoje às ${a.hora}'
        '${a.servicoNome.isEmpty ? '' : ' para ${a.servicoNome.toLowerCase()}'}.';
    final abriu = await abrirWhatsApp(
      telefone: a.clienteTelefone,
      texto: texto,
    );
    if (!abriu && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não deu para abrir o WhatsApp.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a aba estiver aberta
    final provider = ref.watch(resumoProvider);
    final negocio = ref.watch(negocioAtualProvider);

    return Scaffold(
      body: comSombraEmBaixo(
        ListenableBuilder(
          listenable: provider,
          builder: (context, _) {
            return SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _Cabecalho(
                    nome: primeiroNome(negocio.perfil?.nome ?? ''),
                    logoUrl: negocio.logoUrl,
                    negocio: negocio.nome,
                  ),
                  _Filtros(
                    provider: provider,
                    onPeriodo: () => _escolherPeriodo(provider),
                    onProfissional: provider.filtraPorProfissional
                        ? () => _escolherProfissional(provider)
                        : null,
                  ),
                  if (provider.isLoading && provider.carregado)
                    const LinearProgressIndicator(minHeight: 2)
                  else
                    const SizedBox(height: 2),
                  Expanded(child: _corpo(provider, negocio)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _corpo(ResumoProvider provider, NegocioAtualProvider negocio) {
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

    final textos = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final minutosAgora = agora.hour * 60 + agora.minute;
    final proximo = proximoDeHoje(
      resumo.agendamentosHoje,
      minutosAgora: minutosAgora,
      isKanban: resumo.isKanban,
    );
    final rotaDaFicha = resumo.isKanban ? '/quadro/' : '/agenda/';
    final rotaDeNovo = resumo.isKanban
        ? '/quadro/novo?data=${dataParaApi(agora)}'
        : '/agenda/novo?data=${dataParaApi(agora)}';
    final comparacao = provider.atalho == AtalhoPeriodo.hoje
        ? 'vs. ontem'
        : 'vs. período anterior';
    final ehProprietario = negocio.ehProprietario;
    final mostraRepasse =
        resumo.repasse != null &&
        (!ehProprietario ||
            resumo.repasse! > Decimal.zero ||
            provider.colaboradorId != null);

    return RefreshIndicator(
      onRefresh: provider.carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ---- o que vem agora ----
          if (proximo != null)
            _ProximoCard(
              atendimento: proximo,
              minutosAgora: minutosAgora,
              isKanban: resumo.isKanban,
              onAbrir: () => _abrir('$rotaDaFicha${proximo.id}'),
              onWhatsApp: proximo.clienteTelefone.isEmpty
                  ? null
                  : () => _whatsApp(proximo),
            )
          else
            _DiaLivreCard(
              isKanban: resumo.isKanban,
              onMarcar: () => _abrir(rotaDeNovo),
            ),

          if (resumo.agendamentosHoje.isNotEmpty) ...[
            const SizedBox(height: 20),
            TituloDaSecao(
              'Hoje',
              detalhe: resumo.isKanban
                  ? '${resumo.agendamentosHoje.length} em andamento'
                  : '${resumo.agendamentosHoje.length} '
                        '${resumo.agendamentosHoje.length == 1 ? 'horário' : 'horários'}',
            ),
            const SizedBox(height: 8),
            _LinhaDoDia(
              atendimentos: resumo.agendamentosHoje,
              proximoId: proximo?.id,
              minutosAgora: minutosAgora,
              isKanban: resumo.isKanban,
              onAbrir: (a) => _abrir('$rotaDaFicha${a.id}'),
            ),
          ],

          // ---- os números do período ----
          const SizedBox(height: 24),
          TituloDaSecao('Números', detalhe: _rotuloDoPeriodo(provider)),
          const SizedBox(height: 12),
          Painel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (resumo.faturamento != null) ...[
                  Text(
                    'Faturamento',
                    style: textos.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          formatarDinheiro(resumo.faturamento!),
                          style: textos.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _Variacao(
                          variacao: resumo.faturamentoVariacao,
                          comparacao: comparacao,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'Atendimentos',
                    style: textos.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${resumo.atendimentos}',
                        style: textos.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _Variacao(
                          variacao: resumo.atendimentosVariacao,
                          comparacao: comparacao,
                        ),
                      ),
                    ],
                  ),
                ],
                // um dia só é um número, não um gráfico: a barra só aparece
                // quando há dias para comparar entre si
                if (resumo.serie.length > 1) ...[
                  const SizedBox(height: 16),
                  GraficoBarras(
                    valores: [
                      for (final p in resumo.serie)
                        resumo.faturamento != null
                            ? (p.faturamento ?? Decimal.zero).toDouble()
                            : p.atendimentos.toDouble(),
                    ],
                    rotulos: [for (final p in resumo.serie) '${p.data.day}'],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (resumo.faturamento != null)
                      Expanded(
                        child: _Tile(
                          rotulo: 'Atendimentos',
                          valor: '${resumo.atendimentos}',
                          variacao: resumo.atendimentosVariacao,
                        ),
                      ),
                    if (resumo.ticketMedio != null)
                      Expanded(
                        child: _Tile(
                          rotulo: 'Ticket médio',
                          valor: formatarDinheiro(resumo.ticketMedio!),
                        ),
                      ),
                    if (resumo.clientesNovos != null)
                      Expanded(
                        child: _Tile(
                          rotulo: 'Clientes novos',
                          valor: '${resumo.clientesNovos}',
                          variacao: resumo.clientesNovosVariacao,
                        ),
                      ),
                  ],
                ),
                if (mostraRepasse) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          // para o dono, o que sai para os parceiros; para
                          // o parceiro, o que ele tem a receber
                          ehProprietario ? 'Repasse a parceiros' : 'A receber',
                          style: textos.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        formatarDinheiro(resumo.repasse!),
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

          // ---- os serviços mais feitos ----
          if (resumo.rankingServicos.isNotEmpty) ...[
            const SizedBox(height: 24),
            const TituloDaSecao('Mais feitos'),
            const SizedBox(height: 12),
            Painel(
              child: Column(
                children: [
                  for (final (i, r) in resumo.rankingServicos.indexed) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _BarraDoRanking(
                      nome: r.nome,
                      total: r.total,
                      maior: resumo.rankingServicos.first.total,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ---- pendências ----
          const SizedBox(height: 24),
          Painel(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Cobranças pendentes'),
              subtitle: Text(
                provider.pendencias == 0
                    ? 'Tudo cobrado'
                    : provider.pendencias == 1
                    ? '1 atendimento sem cobrança'
                    : '${provider.pendencias} atendimentos sem cobrança',
              ),
              trailing: provider.pendencias == 0
                  ? const Icon(Icons.chevron_right)
                  : Badge(
                      label: Text('${provider.pendencias}'),
                      child: const Icon(Icons.chevron_right),
                    ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onTap: () => _abrir('/agenda/pendencias'),
            ),
          ),
        ],
      ),
    );
  }

  String _rotuloDoPeriodo(ResumoProvider provider) {
    switch (provider.atalho) {
      case AtalhoPeriodo.hoje:
        return 'hoje';
      case AtalhoPeriodo.semana:
        return 'últimos 7 dias';
      case AtalhoPeriodo.mes:
        return 'este mês';
      case AtalhoPeriodo.personalizado:
        return mesmoDia(provider.inicio, provider.fim)
            ? formatarData(provider.inicio)
            : '${formatarData(provider.inicio)} a '
                  '${formatarData(provider.fim)}';
    }
  }
}

// a saudação com o nome de quem entrou e a data de hoje; o logo do negócio
// no canto
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.nome,
    required this.logoUrl,
    required this.negocio,
  });

  final String nome;
  final String logoUrl;
  final String negocio;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final hora = DateTime.now().hour;
    final saudacao = hora < 12
        ? 'Bom dia'
        : hora < 18
        ? 'Boa tarde'
        : 'Boa noite';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome.isEmpty ? saudacao : '$saudacao, $nome',
                  style: textos.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  formatarDataPorExtenso(DateTime.now()),
                  style: textos.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AvatarIniciais(nome: negocio, fotoUrl: logoUrl, raio: 20),
        ],
      ),
    );
  }
}

// os dois filtros, com o mesmo desenho: o período e, para o dono, o
// profissional. cada um abre a folha de opções
class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.provider,
    required this.onPeriodo,
    this.onProfissional,
  });

  final ResumoProvider provider;
  final VoidCallback onPeriodo;
  final VoidCallback? onProfissional;

  @override
  Widget build(BuildContext context) {
    final periodo = switch (provider.atalho) {
      AtalhoPeriodo.hoje => 'Hoje',
      AtalhoPeriodo.semana => '7 dias',
      AtalhoPeriodo.mes => 'Este mês',
      AtalhoPeriodo.personalizado =>
        mesmoDia(provider.inicio, provider.fim)
            ? formatarData(provider.inicio)
            : '${provider.inicio.day}/${provider.inicio.month} a '
                  '${provider.fim.day}/${provider.fim.month}',
    };
    final Colaborador? escolhido = provider.colaboradores
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
          if (onProfissional != null && provider.colaboradores.isNotEmpty) ...[
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

// o card do próximo atendimento: hora grande, a contagem, quem e o quê, e
// os dois atalhos (abrir a ficha, avisar no WhatsApp)
class _ProximoCard extends StatelessWidget {
  const _ProximoCard({
    required this.atendimento,
    required this.minutosAgora,
    required this.isKanban,
    required this.onAbrir,
    this.onWhatsApp,
  });

  final AgendamentoHoje atendimento;
  final int minutosAgora;
  final bool isKanban;
  final VoidCallback onAbrir;
  final VoidCallback? onWhatsApp;

  // perto é dentro de 15 minutos: hora de a pessoa se preparar
  static const _minutosPerto = 15;

  int get _diff => atendimento.minutos - minutosAgora;
  bool get _perto => !isKanban && _diff <= _minutosPerto;

  String get _contagem {
    if (isKanban) return 'Em andamento';
    final diff = _diff;
    if (diff <= 0) return 'Agora';
    if (diff <= 60) return 'Em $diff min';
    final h = diff ~/ 60;
    final m = diff % 60;
    return m == 0 ? 'Em ${h}h' : 'Em ${h}h${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final a = atendimento;
    final sobre = colors.onPrimary;
    // a pílula da contagem fica laranja pastel quando está perto (até 15
    // min), para não gritar sobre o azul; no resto, branco translúcido
    final (fundoDaPilula, textoDaPilula, iconeDaPilula) = _perto
        ? (const Color(0xFFFFD9A8), const Color(0xFF6B3D00), Icons.bolt)
        : (sobre.withValues(alpha: 0.18), sobre, null);
    final detalhe = [
      if (a.servicoNome.isNotEmpty) a.servicoNome,
      if (a.colaboradorNome.isNotEmpty) a.colaboradorNome,
    ].join(' · ');

    return Material(
      color: colors.primary,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAbrir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isKanban ? 'Na esteira' : 'Próximo',
                    style: textos.labelLarge?.copyWith(
                      color: sobre.withValues(alpha: 0.8),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: fundoDaPilula,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (iconeDaPilula != null) ...[
                          Icon(iconeDaPilula, size: 14, color: textoDaPilula),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          _contagem,
                          style: textos.labelMedium?.copyWith(
                            color: textoDaPilula,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    a.hora,
                    style: textos.displaySmall?.copyWith(
                      color: sobre,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.clienteNome,
                          style: textos.titleMedium?.copyWith(
                            color: sobre,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (detalhe.isNotEmpty)
                          Text(
                            detalhe,
                            style: textos.bodyMedium?.copyWith(
                              color: sobre.withValues(alpha: 0.85),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onAbrir,
                    style: TextButton.styleFrom(
                      foregroundColor: sobre,
                      backgroundColor: sobre.withValues(alpha: 0.14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Abrir'),
                  ),
                  if (onWhatsApp != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onWhatsApp,
                      style: TextButton.styleFrom(
                        foregroundColor: sobre,
                        backgroundColor: sobre.withValues(alpha: 0.14),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('Avisar'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// nada à frente hoje
class _DiaLivreCard extends StatelessWidget {
  const _DiaLivreCard({required this.isKanban, required this.onMarcar});

  final bool isKanban;
  final VoidCallback onMarcar;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Painel(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colors.secondaryContainer,
            child: Icon(
              Icons.event_available_outlined,
              color: colors.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isKanban ? 'Esteira vazia' : 'Nada à frente hoje',
                  style: textos.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isKanban
                      ? 'Nenhum atendimento em andamento.'
                      : 'Nenhum horário marcado daqui para a frente.',
                  style: textos.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: onMarcar,
            child: Text(isKanban ? 'Receber' : 'Marcar'),
          ),
        ],
      ),
    );
  }
}

// a linha do dia: uma pílula por horário, em ordem. a do próximo fica na
// primária, as que já passaram ficam apagadas
class _LinhaDoDia extends StatelessWidget {
  const _LinhaDoDia({
    required this.atendimentos,
    required this.proximoId,
    required this.minutosAgora,
    required this.isKanban,
    required this.onAbrir,
  });

  final List<AgendamentoHoje> atendimentos;
  final int? proximoId;
  final int minutosAgora;
  final bool isKanban;
  final ValueChanged<AgendamentoHoje> onAbrir;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final lista = [...atendimentos]
      ..sort((a, b) => a.minutos.compareTo(b.minutos));

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: lista.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final a = lista[i];
          final ehProximo = a.id == proximoId;
          final passou = !isKanban && !ehProximo && a.minutos < minutosAgora;
          final fundo = ehProximo
              ? colors.primary
              : colors.surfaceContainerHigh;
          final texto = ehProximo
              ? colors.onPrimary
              : passou
              ? colors.outline
              : colors.onSurface;

          return Material(
            color: fundo,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onAbrir(a),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      a.hora,
                      style: textos.titleSmall?.copyWith(
                        color: texto,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      primeiroNome(a.clienteNome),
                      style: textos.bodySmall?.copyWith(
                        color: ehProximo
                            ? colors.onPrimary.withValues(alpha: 0.85)
                            : texto,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// a variação sobre o período anterior numa pílula pequena, em verde ou
// vermelho suaves; sem base de comparação, não aparece
class _Variacao extends StatelessWidget {
  const _Variacao({required this.variacao, required this.comparacao});

  final int? variacao;
  final String comparacao;

  @override
  Widget build(BuildContext context) {
    final v = variacao;
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    if (v == null) return const SizedBox.shrink();
    final cor = v > 0
        ? Colors.green.shade700
        : v < 0
        ? colors.error
        : colors.onSurfaceVariant;
    final icone = v > 0
        ? Icons.arrow_upward
        : v < 0
        ? Icons.arrow_downward
        : Icons.remove;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 12, color: cor),
              const SizedBox(width: 2),
              Text(
                '${v.abs()}%',
                style: textos.labelSmall?.copyWith(
                  color: cor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          comparacao,
          style: textos.labelSmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

// um número secundário: rótulo, valor e a variação miúda
class _Tile extends StatelessWidget {
  const _Tile({required this.rotulo, required this.valor, this.variacao});

  final String rotulo;
  final String valor;
  final int? variacao;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final v = variacao;
    final cor = v == null || v == 0
        ? colors.onSurfaceVariant
        : v > 0
        ? Colors.green.shade700
        : colors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: textos.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (v != null)
          Text(
            '${v > 0
                ? '▲'
                : v < 0
                ? '▼'
                : '•'} ${v.abs()}%',
            style: textos.labelSmall?.copyWith(color: cor),
          ),
      ],
    );
  }
}

// uma linha do ranking: nome, a barra proporcional ao mais feito, o total
class _BarraDoRanking extends StatelessWidget {
  const _BarraDoRanking({
    required this.nome,
    required this.total,
    required this.maior,
  });

  final String nome;
  final int total;
  final int maior;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final fracao = maior == 0 ? 0.0 : total / maior;

    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            nome,
            style: textos.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fracao,
              minHeight: 8,
              backgroundColor: colors.surfaceContainerHighest,
              color: colors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 28,
          child: Text(
            '$total',
            textAlign: TextAlign.right,
            style: textos.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
